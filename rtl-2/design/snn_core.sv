`include "synaptic_ram.sv"
`include "lif_neuron.sv"
module snn_core #(
    parameter NUM_INPUTS = 256
)(
    input wire clk,
    input wire rst_n,
    
    // --- User Programming Interface ---
    input wire program_mode,              
    input wire [7:0] prog_addr,
    input wire signed [7:0] prog_data,
    input wire prog_wr_en,
    
    // --- Inference Interface ---
    input wire start_tick,                
    input wire [7:0] current_input_val,  
    output wire [7:0] input_read_addr,    
    output wire neuron_fire,
    output wire signed [15:0] monitor_potential,
    output reg busy
);

    // Internal Signals
    reg [7:0] synapse_idx; 
    reg signed [15:0] current_sum;
    
    // Sub-module Interconnects
    wire [7:0] rng_val;
    wire signed [7:0] weight_from_ram;
    wire lif_fire;
    reg lif_update_en;

    // --- MUX: RAM Control ---
    wire [7:0] ram_addr_mux;
    wire ram_we_mux;
    assign ram_addr_mux = (program_mode) ? prog_addr  : synapse_idx;
    assign ram_we_mux   = (program_mode) ? prog_wr_en : 1'b0;

    // --- Instantiations ---
    xor_shift_rng rng_inst (
        .clk(clk), .rst_n(rst_n), .random_out(rng_val)
    );

    synaptic_ram #(.NUM_SYNAPSES(NUM_INPUTS)) syn_ram_inst (
        .clk(clk),
        .write_enable(ram_we_mux),
        .address(ram_addr_mux),
        .data_in(prog_data),
        .weight_out(weight_from_ram)
    );

    lif_neuron #(.THRESHOLD(16'd1000), .LEAK_SHIFT(3)) neuron_inst (
        .clk(clk), .rst_n(rst_n),
        .update_enable(lif_update_en),
        .input_sum(current_sum),
        .fire(neuron_fire),
        .potential(monitor_potential)
    );

    // Address Output to External Input Memory
    assign input_read_addr = synapse_idx;

    localparam STATE_IDLE = 0, STATE_PROCESS = 1, STATE_UPDATE = 2;
    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            synapse_idx <= 0;
            current_sum <= 0;
            busy <= 0;
            lif_update_en <= 0;
        end else begin
            if (program_mode) begin
                state <= STATE_IDLE;
                busy <= 0;
            end else begin
                lif_update_en <= 0; // Default

                case (state)
                    STATE_IDLE: begin
                        busy <= 0;
                        if (start_tick) begin
                            state <= STATE_PROCESS;
                            synapse_idx <= 0;
                            current_sum <= 0;
                            busy <= 1;
                        end
                    end

                    STATE_PROCESS: begin
                        // --- POISSON LOGIC ---
                        // Compare External Input Value vs Internal Random Number
                        if (current_input_val > rng_val) begin
                            current_sum <= current_sum + weight_from_ram;
                        end

                    
                        if (synapse_idx == NUM_INPUTS - 1) begin
                            state <= STATE_UPDATE;
                        end else begin
                            synapse_idx <= synapse_idx + 1;
                        end
                    end

                    STATE_UPDATE: begin
                        lif_update_en <= 1; 
                        state <= STATE_IDLE;
                    end
                endcase
            end
        end
    end
endmodule
