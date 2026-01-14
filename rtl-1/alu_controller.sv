`timescale 1ns / 1ps

module layer_controller #(
    parameter int NUM_NEURONS = 10,
    parameter int IMAGE_SIZE  = 784
)(
    input  logic clk,
    input  logic rst_n,
    input  logic start_layer,
    
    // Feedback from Neurons
    input  logic [NUM_NEURONS-1:0] neuron_fired_flags, 
    input  logic [NUM_NEURONS-1:0] neuron_valid_flags, 
    
    // Controls to Neurons
    output logic [NUM_NEURONS-1:0] neuron_enables,
    
    // Status Outputs
    output logic step_done,        // High ONLY in S3
    output logic layer_data_valid, // High ONLY in S4
    output logic [NUM_NEURONS-1:0] spike_vector
);

    // ============================================================
    // 1. FSM State Definitions
    // ============================================================
    typedef enum logic [1:0] {
        S0_IDLE,        // Idle / Wait for Start
        S1_COMPUTE,     // Computing current pixel
        S3_STEP_DONE,   // Pixel Count != 783 (Increment & Pulse step_done)
        S4_LAYER_DONE   // Pixel Count == 783 (Output Valid)
    } state_t;

    state_t current_state, next_state;

    // Internal Registers
    logic [10:0] pixel_cnt;
    logic [NUM_NEURONS-1:0] active_mask;      // 1=Alive, 0=Fired/Dead
    logic [NUM_NEURONS-1:0] spikes_captured;  // Stores results
    logic [NUM_NEURONS-1:0] done_latches;     // Tracks completion of CURRENT pixel

    logic all_active_neurons_ready;

    // Handshake Logic:
    // Ready if all active neurons have latched 'done'.
    // (~active_mask) forces disabled neurons to appear 'ready' automatically.
    assign all_active_neurons_ready = & (done_latches | ~active_mask);


    // ============================================================
    // BLOCK 1: State Register (Sequential)
    // ============================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            current_state <= S0_IDLE;
        else 
            current_state <= next_state;
    end


    // ============================================================
    // BLOCK 2: Next State Logic (Combinational)
    // ============================================================
    always_comb begin
        next_state = current_state; // Default: Stay in current state

        case (current_state)
            // --- S0: IDLE ---
            S0_IDLE: begin
                if (start_layer) 
                    next_state = S1_COMPUTE;
            end

            // --- S1: COMPUTATION ---
            S1_COMPUTE: begin
                // Wait until all active neurons produce valid flags
                if (all_active_neurons_ready) begin
                    // BRANCHING LOGIC:
                    if (pixel_cnt != IMAGE_SIZE - 1)
                        next_state = S3_STEP_DONE; // Go to S3 if not finished
                    else
                        next_state = S4_LAYER_DONE; // Go to S4 if finished (783)
                end
            end

            // --- S3: STEP DONE (Intermediate Pixel) ---
            S3_STEP_DONE: begin
                // Unconditional return to Compute for the next pixel
                next_state = S0_IDLE;
            end

            // --- S4: LAYER DONE (Finished) ---
            S4_LAYER_DONE: begin
                // Wait for Master to drop start signal or reset
                if (!start_layer)
                    next_state = S0_IDLE;
            end
        endcase
    end


    // ============================================================
    // BLOCK 3: Datapath & Control Signal Generation (Sequential)
    // ============================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_cnt        <= 0;
            active_mask      <= '1; // Enable all
            spikes_captured  <= '0;
            done_latches     <= '0;
            step_done        <= 0;
            layer_data_valid <= 0;
        end else begin
            
            // Default: Clear Pulse
            step_done <= 0;

            case (current_state)
                
                // --- S0: IDLE ---
                S0_IDLE: begin
                    
                     // Reset masks
                     // Clear results
                    done_latches     <= '0;
                    layer_data_valid <= 0;
                    step_done        <= 0;
                end

                // --- S1: COMPUTE ---
                S1_COMPUTE: begin
                    // 1. Capture 'Done' signals from neurons (Accumulate them)
                    done_latches <= done_latches | neuron_valid_flags;

                    // 2. Capture Spikes & Disable fired neurons (First-to-spike logic)
                    for (int i = 0; i < NUM_NEURONS; i++) begin
                        if (neuron_fired_flags[i]) begin
                            spikes_captured[i] <= 1'b1;
                            active_mask[i]     <= 1'b0; 
                        end
                    end
                end

                // --- S3: STEP DONE ---
                // We arrive here if pixel_cnt != 783. 
                S3_STEP_DONE: begin
                    step_done    <= 1;          // Pulse output High
                    pixel_cnt    <= pixel_cnt + 1; // Increment Counter
                    done_latches <= 0;        // Clear latches for NEXT pixel
                end

                // --- S4: LAYER DONE ---
                // We arrive here if pixel_cnt == 783.
                S4_LAYER_DONE: begin
                    layer_data_valid <= 1; // Signal Validity to outside world
                    step_done        <= 0;
                    // Spikes and Mask remain latched/frozen here
                end

            endcase
        end
    end


    // ============================================================
    // 4. Output Logic (Combinational)
    // ============================================================
    
    // Enable Logic:
    // "Tenables" go high ONLY in S1 (Compute).
    // They must also be in the active mask and not yet finished with the current pixel.
    assign neuron_enables = {NUM_NEURONS{current_state == S1_COMPUTE}} & 
                            active_mask & 
                            ~done_latches;

    assign spike_vector = spikes_captured;

endmodule