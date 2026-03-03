`timescale 1ns / 1ps

module tb_network();

    // Parameters
    localparam NUM_INPUTS = 16; 
    localparam NUM_NEURONS = 10;
    localparam CLK_PERIOD = 10;

    // Signals
    reg clk;
    reg rst_n;
    
    // Programming Interface
    reg program_mode;              
    reg [$clog2(NUM_NEURONS)-1:0] prog_neuron_addr;
    reg [$clog2(NUM_INPUTS)-1:0] prog_addr;
    reg signed [7:0] prog_weight_data;
    reg prog_weight_we;
    
    // Inference Interface
    reg start_tick;                
    reg [7:0] pixel_val; 
    
    // Outputs
    wire [NUM_NEURONS-1:0] neuron_fire;
    wire [(NUM_NEURONS*16)-1:0] monitor_potential_bus;
    wire busy;

    // Simulated External Pixel Buffer
    reg [7:0] test_pixels [0:NUM_INPUTS-1];

    // Device Under Test (DUT)
    network #(
        .NUM_INPUTS(NUM_INPUTS),
        .NUM_NEURONS(NUM_NEURONS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .program_mode(program_mode),
        .prog_neuron_addr(prog_neuron_addr),
        .prog_addr(prog_addr),
        .prog_weight_data(prog_weight_data),
        .prog_weight_we(prog_weight_we),
        .start_tick(start_tick),
        .pixel_val(pixel_val),
        .neuron_fire(neuron_fire),
        .monitor_potential_bus(monitor_potential_bus),
        .busy(busy)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end


    always @(posedge clk) begin
        
        if (rst_n && dut.busy_array[0]) begin
            $display("  [Time: %6t] Streamed Pixel: %3d | Poisson RNG: %3d | Generated Raw Spike: %b",
                     $time, pixel_val, dut.rng_val, dut.raw_spike);
        end
    end

    // --- Test Stimulus ---
    integer i, n;
    integer tick_count;
    reg signed [15:0] extracted_potential;
    
    initial begin
        // 1. Initialize Signals
        rst_n = 0;
        program_mode = 0;
        prog_neuron_addr = 0;
        prog_addr = 0;
        prog_weight_data = 0;
        prog_weight_we = 0;
        start_tick = 0;
        pixel_val = 0;
        
        // 2. Setup the "Image" (Solid bright image to force spikes)
        for (i = 0; i < NUM_INPUTS; i = i + 1) begin
            test_pixels[i] = 8'd220; 
        end

        // Wait for reset
        #(CLK_PERIOD * 2);
        rst_n = 1;
        #(CLK_PERIOD * 2);

        $display("\n==============================================");
        $display("--- Starting 10-Neuron Systolic Array Simulation ---");
        $display("==============================================\n");

        // ==========================================
        // Program the Synaptic Weights
        // ==========================================
        $display("Programming Synaptic Weights...");
        program_mode = 1;
        
        // DIFFERENT weight
        // Neuron 0 gets weight 10, Neuron 1 gets 11, Neuron 9 gets 19.
        // their potentials rise at different rates
        for (n = 0; n < NUM_NEURONS; n = n + 1) begin
            for (i = 0; i < NUM_INPUTS; i = i + 1) begin
                @(posedge clk);
                prog_neuron_addr = n;
                prog_addr  = i;
                prog_weight_data  = 10 + n; 
                prog_weight_we = 1;
            end
        end
        
        @(posedge clk);
        prog_weight_we = 0;
        program_mode = 0; 
        #(CLK_PERIOD * 5);

        // ==========================================
        // Run Inference Ticks (Streaming Data)
        // ==========================================
        
        for (tick_count = 1; tick_count <= 4; tick_count = tick_count + 1) begin
            $display("\n----------------------------------------------");
            $display(" Triggering Inference Tick %0d at time %0t", tick_count, $time);
            $display("----------------------------------------------");
            
            // Pulse start_tick
            @(posedge clk);
            start_tick = 1;
            
            
            @(posedge clk);
            start_tick = 0;
            
            for (i = 0; i < NUM_INPUTS; i = i + 1) begin
                pixel_val = test_pixels[i];
                @(posedge clk); 
            end
            
            // Clear the pixel bus after streaming is done
            pixel_val = 0;

            // Wait until the ENTIRE systolic array finishes
            wait(busy == 0);
            
            
            @(posedge clk);
            
            // ==========================================
            // End-of-Tick Scoreboard
            // ==========================================
            $display("\n>>> TICK %0d COMPLETE <<<", tick_count);
            $display("==============================================");
            $display(" NEURON | POTENTIAL | FIRED?");
            $display("----------------------------------------------");
            
            for (n = 0; n < NUM_NEURONS; n = n + 1) begin
                
                extracted_potential = monitor_potential_bus[(n*16) +: 16];
                
                $display("   %2d   |   %5d   |   %b", 
                         n, extracted_potential, neuron_fire[n]);
            end
            $display("==============================================\n");
            
            #(CLK_PERIOD * 10); // Delay between ticks
        end

        // ==========================================
        // Finish
        // ==========================================
        $display("\n==============================================");
        $display("--- Simulation Complete ---");
        $display("==============================================\n");
        $finish;
    end

    // --- Waveform Dump ---
//    initial begin
//        $dumpfile("snn_wave.vcd");
//        $dumpvars(0, tb_network);
//    end

endmodule