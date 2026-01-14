`timescale 1ns / 1ps

module snn_network_array #(
    parameter int DATA_WIDTH = 8,
    parameter int NUM_NEURONS = 10
)(
    input  logic clk,
    input  logic rst_n,
    input  logic [DATA_WIDTH-1:0] pixel_in,
    
    // Config Arrays
    input  logic [NUM_NEURONS-1:0][15:0] weights_all,
    input  logic [NUM_NEURONS-1:0][15:0] decays_all,
    input  logic [NUM_NEURONS-1:0][15:0] thresh_all,
    
    // Control Interface
    input  logic [NUM_NEURONS-1:0] enables_in,
    
    // Outputs
    output logic [NUM_NEURONS-1:0] fired_flags_out,  // 'result'
    output logic [NUM_NEURONS-1:0] valid_flags_out   // 'data_valid'
);

    genvar g;
    generate
        for (g = 0; g < NUM_NEURONS; g++) begin : neurons
            lif_neuron_top #(
                .DATA_WIDTH(DATA_WIDTH)
            ) u_lif_node (
                .clk        (clk),
                .rst_n      (rst_n),
                .enable     (enables_in[g]),
                .a          (pixel_in),
                
                // Config
                .weight_val (weights_all[g]),
                .decay_val  (decays_all[g]),
                .thresh_val (thresh_all[g]),
                
                // Outputs
                .data_valid (valid_flags_out[g]), // Connect to array output
                .result     (fired_flags_out[g])
            );
        end
    endgenerate

endmodule