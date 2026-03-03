`timescale 1ns / 1ps

module snn_top #(
    parameter NUM_INPUTS = 256
)(
    input wire clk,
    input wire rst_n,

    // Programming Interface (Weights Only)
    input wire program_mode,              
    input wire [$clog2(NUM_INPUTS)-1:0] prog_addr,
    input wire signed [7:0] prog_weight_data,
    input wire prog_weight_we,

    // Inference Interface (Streaming)
    input wire start_tick,
    input wire [7:0] pixel_val,    // Synchronous streaming pixel value
    
    output wire neuron_fire,
    output wire signed [15:0] monitor_potential,
    output wire busy
);

    // Internal Signals
    wire [7:0] rng_val;
    wire current_spike;

    // The Poisson Spike Generator
    
    assign current_spike = (pixel_val > rng_val) ? 1'b1 : 1'b0;
    
    // Instantiations
    // The RNG (Generates a new random number every single clock cycle)
    xor_shift_rng rng_inst (
        .clk(clk), 
        .rst_n(rst_n), 
        .random_out(rng_val)
    );


    snn_core #(.NUM_INPUTS(NUM_INPUTS)) core_inst (
        .clk(clk),
        .rst_n(rst_n),
        .program_mode(program_mode),
        .prog_addr(prog_addr),
        .prog_data(prog_weight_data),
        .prog_wr_en(prog_weight_we),
        .start_tick(start_tick),
        .spike(current_spike),           // Directly feeds the generated 1-bit spike into the core pipeline
        .neuron_fire(neuron_fire),
        .monitor_potential(monitor_potential),
        .busy(busy)
    );

endmodule