`timescale 1ns / 1ps

module tb_snn_top();

    // Parameters
    localparam NUM_INPUTS = 16; 
    localparam CLK_PERIOD = 10;

    // Signals
    reg clk;
    reg rst_n;
    
    // Programming Interface
    reg program_mode;              
    reg [$clog2(NUM_INPUTS)-1:0] prog_addr;
    reg signed [7:0] prog_weight_data;
    reg prog_weight_we;
    
    // Inference Interface
    reg start_tick;                
    reg [7:0] pixel_val; // Synchronous streaming pixel value
    
    wire neuron_fire;
    wire signed [15:0] monitor_potential;
    wire busy;

    // Simulated External Pixel Buffer
    // This holds the 8-bit image pixels we want to stream into the core
    reg [7:0] test_pixels [0:NUM_INPUTS-1];

    // Device Under Test (DUT)
    snn_top #(
        .NUM_INPUTS(NUM_INPUTS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .program_mode(program_mode),
        .prog_addr(prog_addr),
        .prog_weight_data(prog_weight_data),
        .prog_weight_we(prog_weight_we),
        .start_tick(start_tick),
        .pixel_val(pixel_val),
        .neuron_fire(neuron_fire),
        .monitor_potential(monitor_potential),
        .busy(busy)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end


    always @(posedge clk) begin
        if (rst_n && dut.core_inst.state == 2'd1 && dut.core_inst.synapse_idx > 0) begin
            $display("    [Time: %6t] SynIdx: %2d | Streamed Pixel: %3d | RNG: %3d | Spike Gen: %b | Weight: %3d | Accum Sum (Before Add): %4d",
                     $time,
                     dut.core_inst.synapse_idx - 1,    
                     pixel_val,                        // The 8-bit pixel streamed from TB
                     dut.rng_val,                      // RNG generated inside Top
                     dut.current_spike,                // Evaluated spike inside Top
                     dut.core_inst.weight_from_ram,    // Weight pulled from BRAM
                     dut.core_inst.current_sum);       // Running sum
        end
    end

    // Test Stimulus
    integer i, j;
    integer tick_count;
    
    initial begin
        // 1. Initialize Signals
        rst_n = 0;
        program_mode = 0;
        prog_addr = 0;
        prog_weight_data = 0;
        prog_weight_we = 0;
        start_tick = 0;
        pixel_val = 0;
        
        // 2. Setup the "Image" (Pixel Array)
        // We set high pixel intensities (200) to ensure plenty of Poisson spikes
        for (i = 0; i < NUM_INPUTS; i = i + 1) begin
            test_pixels[i] = 8'd200; 
        end

        // Wait for reset
        #(CLK_PERIOD * 2);
        rst_n = 1;
        #(CLK_PERIOD * 2);

        $display("\n==============================================");
        $display("--- Starting SNN Streaming Simulation ---");
        $display("==============================================\n");

        // ==========================================
        // Program the Synaptic Weights
        // ==========================================
        $display("Programming Synaptic Weights to 15...");
        program_mode = 1;
        
        for (i = 0; i < NUM_INPUTS; i = i + 1) begin
            @(posedge clk);
            prog_addr  = i;
            prog_weight_data  = 8'd15; // Set weights to 15
            prog_weight_we = 1;
        end
        
        @(posedge clk);
        prog_weight_we = 0;
        program_mode = 0; // Exit programming mode
        #(CLK_PERIOD * 2);

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
            
            // On the EXACT NEXT clock cycle, drop start_tick and start pumping pixels
            @(posedge clk);
            start_tick = 0;
            
            for (j = 0; j < NUM_INPUTS; j = j + 1) begin
                pixel_val = test_pixels[j];
                @(posedge clk); // Hold each pixel for exactly 1 clock cycle
            end
            
            // Clear the pixel bus after streaming is done
            pixel_val = 0;

            // Wait until the core finishes processing the pipeline
            wait(busy == 0);
            
            // Wait one extra clock cycle to observe the LIF neuron update phase
            @(posedge clk);
            
            $display(">>> TICK %0d COMPLETE <<<", tick_count);
            $display(">>> Final Accumulated Sum sent to Neuron: %0d", dut.core_inst.current_sum);
            $display(">>> New Neuron Potential: %0d", monitor_potential);
            $display(">>> Did Neuron Fire?: %0b", neuron_fire);
            
            #(CLK_PERIOD * 5); // Delay between ticks visually
        end

        // ==========================================
        // Finish
        // ==========================================
        $display("\n==============================================");
        $display("--- Simulation Complete ---");
        $display("==============================================\n");
        $finish;
    end

    // Waveform Dump
    initial begin
        $dumpfile("snn_wave.vcd");
        $dumpvars(0, tb_snn_top);
    end

endmodule