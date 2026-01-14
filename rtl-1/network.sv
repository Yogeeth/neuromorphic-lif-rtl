`timescale 1ns / 1ps

module lif_neuron_top #(
    parameter int DATA_WIDTH = 8
)(
    input  logic clk,
    input  logic rst_n,       // Active Low Reset
    input  logic enable,
    input  logic [DATA_WIDTH-1:0] a,
    
    // Dynamic Inputs driven by Testbench
    input  logic [15:0] weight_val,
    input  logic [15:0] decay_val,
    input  logic [15:0] thresh_val,
    output logic data_valid,
    
    output logic result       // 1-bit Spike Output
);

    // ============================================================
    // 1. Internal Signals
    // ============================================================
    logic rst_active_high;
    assign rst_active_high = ~rst_n;
    
    logic spike_wire;
    logic spike_valid_wire;
    
    // Controller -> Neuron Control Signals
    logic c_acc_en, c_comp_en, c_decay_en;
    logic c_mult_en, c_thresh_en, c_weight_en, c_spike_en;
    logic c_store_en; 
    
    logic c_acc_rst, c_comp_rst, c_decay_rst;
    logic c_mult_rst, c_thresh_rst, c_weight_rst, c_spike_rst;
    logic c_store_rst;
    
    logic c_mux_in;

    
    logic ctrl_data_valid;
    logic [15:0] spike_count_debug, cycle_count_debug;
    logic stats_overflow_debug;
    assign data_valid= ctrl_data_valid;
    // ============================================================
    // 2. Module Instantiations
    // ============================================================

    // --- 1. Poisson Encoder ---
    poisson_encoder #( .DATA_WIDTH(DATA_WIDTH), .ENABLE_STATISTICS(0) ) u_encoder (
        .clk(clk),
        .rst_n( ~c_spike_rst),
        .enable(c_spike_en),
        .a(a),
        .spike_out(spike_wire),
        .spike_valid(spike_valid_wire),
        .spike_count(spike_count_debug),
        .cycle_count(cycle_count_debug),
        .stats_overflow(stats_overflow_debug)
    );

    // --- 2. Controller ---
    controller u_controller (
        .clk(clk),
        .rst(rst_active_high),
        .spike_valid(spike_valid_wire),
        .calc_en(enable),
        .comp_out(result), // Feedback: Reset if neuron fires
        
        // Outputs
        .mux_in(c_mux_in),
        .store_en(c_store_en),   .store_rst(c_store_rst),
        .acc_en(c_acc_en),       .acc_rst(c_acc_rst),
        .comp_en(c_comp_en),     .comp_rst(c_comp_rst),
        .decay_en(c_decay_en),   .decay_rst(c_decay_rst),
        .mult_en(c_mult_en),     .mult_rst(c_mult_rst),
        .thresh_en(c_thresh_en), .thresh_rst(c_thresh_rst),
        .weight_en(c_weight_en), .weight_rst(c_weight_rst),
        .spike_en(c_spike_en),   .spike_rst(c_spike_rst),
        .data_valid(ctrl_data_valid)
    );

    // --- 3. Neuron ---
    neuron u_neuron (
        .clk(clk),
        .spike(spike_wire),
        .spike_valid(spike_valid_wire),
        
        // Inputs from Testbench
        .weight_mem(weight_val),
        .decay_mem(decay_val),
        .thresh_mem(thresh_val),
        
        .mux_in(c_mux_in),

        // Controls
        .acc_en(c_acc_en),       .acc_rst(c_acc_rst),
        .comp_en(c_comp_en),     .comp_rst(c_comp_rst),
        .decay_en(c_decay_en),   .decay_rst(c_decay_rst),
        .mult_en(c_mult_en),     .mult_rst(c_mult_rst),
        .thresh_en(c_thresh_en), .thresh_rst(c_thresh_rst),
        .weight_en(c_weight_en), .weight_rst(c_weight_rst),
       
        .store_en(c_store_en),   .store_rst(c_store_rst),
        
        .result(result)
    );

endmodule