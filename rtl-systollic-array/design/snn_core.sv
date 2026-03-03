`timescale 1ns / 1ps

module snn_core #(
    parameter NUM_INPUTS = 256
)(
    input wire clk,
    input wire rst_n,
    
    // User Programming Interface
    input wire program_mode,               // 1 = program weights, 0 = inference
    input wire [$clog2(NUM_INPUTS)-1:0] prog_addr,
    input wire signed [7:0] prog_data,
    input wire prog_wr_en,
    
    // Inference Interface
    input wire start_tick,                
    input wire spike,                      // Input spike (1 or 0)
    output wire neuron_fire,               // Neuron spike output
    output wire signed [15:0] monitor_potential, // For monitoring membrane potential
    output reg busy                        // High while processing tick
);

    // Internal Signals
    reg [$clog2(NUM_INPUTS):0] synapse_idx; 
    reg signed [15:0] current_sum;
    
    // Sub-module interconnects
    wire signed [7:0] weight_from_ram;
    wire lif_fire;
    reg lif_update_en;

    // RAM mux signals
    wire [$clog2(NUM_INPUTS)-1:0] ram_addr_mux;
    wire ram_we_mux;
    
    assign ram_addr_mux = (program_mode) ? prog_addr  : synapse_idx[$clog2(NUM_INPUTS)-1:0];
    assign ram_we_mux   = (program_mode) ? prog_wr_en : 1'b0;

    // Weight memory
    synaptic_ram #(.NUM_SYNAPSES(NUM_INPUTS)) syn_ram_inst (
        .clk(clk),
        .write_enable(ram_we_mux),
        .address(ram_addr_mux),
        .data_in(prog_data),
        .weight_out(weight_from_ram)
    );

    // LIF neuron
    lif_neuron #(.THRESHOLD(16'd1000), .LEAK_SHIFT(3)) neuron_inst (
        .clk(clk), .rst_n(rst_n),
        .update_enable(lif_update_en),
        .input_sum(current_sum),
        .fire(neuron_fire),
        .potential(monitor_potential)
    );

    // State Machine
    localparam STATE_IDLE    = 2'd0;
    localparam STATE_PROCESS = 2'd1;
    localparam STATE_UPDATE  = 2'd2;
    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all state
            state <= STATE_IDLE;
            synapse_idx <= 0;
            current_sum <= 0;
            busy <= 0;
            lif_update_en <= 0;
        end else begin
            if (program_mode) begin
                // Weight programming mode
                state <= STATE_IDLE;
                busy <= 0;
                lif_update_en <= 0;
            end else begin
                lif_update_en <= 0; 

                case (state)
                    STATE_IDLE: begin
                        busy <= 0;
                        if (start_tick) begin
                            // Start processing a new tick
                            state <= STATE_PROCESS;
                            synapse_idx <= 0;
                            current_sum <= 0;
                            busy <= 1;
                        end
                    end

                    STATE_PROCESS: begin
                        // Accumulate input spikes multiplied by weights
                        // External system must align 'spike' with synapse_idx (pipeline delay)
                        if (synapse_idx > 0) begin
                            if (spike) begin 
                                current_sum <= current_sum + weight_from_ram;
                            end
                        end

                        if (synapse_idx == NUM_INPUTS) begin
                            // All inputs processed, move to neuron update
                            state <= STATE_UPDATE;
                        end else begin
                            synapse_idx <= synapse_idx + 1;
                        end
                    end

                    STATE_UPDATE: begin
                        // Update LIF neuron with accumulated sum
                        lif_update_en <= 1; 
                        state <= STATE_IDLE;
                    end
                    
                    default: state <= STATE_IDLE;
                endcase
            end
        end
    end
endmodule