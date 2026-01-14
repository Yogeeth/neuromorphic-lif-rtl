`timescale 1ns / 1ps

module alu #(
    parameter int NUM_NEURONS = 10,
    parameter int DATA_WIDTH  = 8,
    parameter int IMAGE_SIZE  = 784
)(
    // --- Global Controls ---
    input  logic clk,
    input  logic rst_n,
    input  logic start,              // Begins the processing of an image
    
    // --- Data Stream ---
    input  logic [DATA_WIDTH-1:0] pixel_data, // Current pixel value provided externally

    // --- Configuration (Weights/Biases) ---
    // Passed directly to the neuron array
    input  logic [NUM_NEURONS-1:0][15:0] weights,
    input  logic [NUM_NEURONS-1:0][15:0] decays,
    input  logic [NUM_NEURONS-1:0][15:0] thresholds,

    // --- Status & Results ---
    output logic step_done,          // High when ONE pixel is finished (requests next pixel)
    output logic layer_done,         // High when ALL pixels are finished
    output logic [NUM_NEURONS-1:0] spikes_out // Final spike vector (The Result)
);

    // ============================================================
    // Internal Connections (Wires)
    // ============================================================
    
    // 1. Controller -> Array (Commands)
    logic [NUM_NEURONS-1:0] internal_enables;

    // 2. Array -> Controller (Feedback)
    logic [NUM_NEURONS-1:0] internal_fired_flags;
    logic [NUM_NEURONS-1:0] internal_valid_flags;

    // ============================================================
    // Instance 1: The Controller (The Brain)
    // Manages the FSM, counts pixels, and aggregates results.
    // ============================================================
    layer_controller #(
        .NUM_NEURONS (NUM_NEURONS),
        .IMAGE_SIZE  (IMAGE_SIZE)
    ) u_controller (
        .clk                (clk),
        .rst_n              (rst_n),
        .start_layer        (start),
        
        // Feedback from Array
        .neuron_fired_flags (internal_fired_flags),
        .neuron_valid_flags (internal_valid_flags),
        
        // Controls to Array
        .neuron_enables     (internal_enables),
        
        // System Outputs
        .step_done          (step_done),       // Pulses high in S3
        .layer_data_valid   (layer_done),      // Goes high in S4
        .spike_vector       (spikes_out)
    );

    // ============================================================
    // Instance 2: The Network Array (The Muscle)
    // Contains the actual LIF neurons performing the math.
    // ============================================================
    snn_network_array #(
        .DATA_WIDTH  (DATA_WIDTH),
        .NUM_NEURONS (NUM_NEURONS)
    ) u_array (
        .clk             (clk),
        .rst_n           (rst_n),
        .pixel_in        (pixel_data),
        
        // Config
        .weights_all     (weights),
        .decays_all      (decays),
        .thresh_all      (thresholds),
        
        // Control Input (from Controller)
        .enables_in      (internal_enables),
        
        // Feedback Outputs (to Controller)
        .fired_flags_out (internal_fired_flags),
        .valid_flags_out (internal_valid_flags)
    );

endmodule