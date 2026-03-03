`timescale 1ns / 1ps

module network #(
    parameter NUM_INPUTS = 256,
    parameter NUM_NEURONS = 10
)(
    input wire clk,
    input wire rst_n,

    // Programming interface
    input wire program_mode,              
    input wire [$clog2(NUM_NEURONS)-1:0] prog_neuron_addr,
    input wire [$clog2(NUM_INPUTS)-1:0] prog_addr,
    input wire signed [7:0] prog_weight_data,
    input wire prog_weight_we,

    // Inference interface
    input wire start_tick,
    input wire [7:0] pixel_val,    
    
    // Outputs
    output wire [NUM_NEURONS-1:0] neuron_fire,
    output wire [(NUM_NEURONS*16)-1:0] monitor_potential_bus,
    output wire busy
);

    // Internal signals
    wire [7:0] rng_val;
    wire raw_spike;

    reg [NUM_NEURONS-1:0] spike_sr;
    reg [NUM_NEURONS-1:0] start_tick_sr;
    wire [NUM_NEURONS-1:0] busy_array;

    // Network busy if any neuron is busy
    assign busy = |busy_array; 

    // Poisson spike generation
    assign raw_spike = (pixel_val > rng_val);

    // Spike and start_tick shift pipeline
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spike_sr <= 0;
            start_tick_sr <= 0;
        end else begin
            spike_sr[0] <= raw_spike;
            start_tick_sr[0] <= start_tick;
            
            for (integer i = 1; i < NUM_NEURONS; i = i + 1) begin
                spike_sr[i] <= spike_sr[i-1];
                start_tick_sr[i] <= start_tick_sr[i-1];
            end
        end
    end

    // RNG instance
    xor_shift_rng rng_inst (
        .clk(clk), 
        .rst_n(rst_n), 
        .random_out(rng_val)
    );

    // Neuron array
    genvar n;
    generate
        for (n = 0; n < NUM_NEURONS; n = n + 1) begin : gen_neurons
            
            // Per-neuron write enable
            wire local_we = (program_mode && (prog_neuron_addr == n)) ? prog_weight_we : 1'b0;
            
            // Routed start tick
            wire local_start_tick = (n == 0) ? start_tick : start_tick_sr[n-1];

            snn_core #(.NUM_INPUTS(NUM_INPUTS)) core_inst (
                .clk(clk),
                .rst_n(rst_n),
                .program_mode(program_mode),
                .prog_addr(prog_addr),
                .prog_data(prog_weight_data),
                .prog_wr_en(local_we),
                .start_tick(local_start_tick),
                .spike(spike_sr[n]),
                .neuron_fire(neuron_fire[n]),
                .monitor_potential(monitor_potential_bus[(n*16) +: 16]),
                .busy(busy_array[n])
            );
        end
    endgenerate

endmodule