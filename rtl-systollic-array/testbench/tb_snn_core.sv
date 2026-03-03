`timescale 1ns / 1ps

module tb_snn_core();

    // --- Parameters ---
    localparam NUM_INPUTS = 16; 
    localparam CLK_PERIOD = 10;

    // --- Signals ---
    reg clk;
    reg rst_n;
    
    // Programming Interface
    reg program_mode;              
    reg [$clog2(NUM_INPUTS)-1:0] prog_addr;
    reg signed [7:0] prog_data;
    reg prog_wr_en;
    
    // Inference Interface
    reg start_tick;                
    reg spike; // Single bit stream input
    
    wire neuron_fire;
    wire signed [15:0] monitor_potential;
    wire busy;

    // --- Simulated External Spike Memory ---
    // This holds the 1s and 0s we want to stream into the core
    reg spike_train [0:NUM_INPUTS-1];

    // --- Device Under Test (DUT) ---
    snn_core #(
        .NUM_INPUTS(NUM_INPUTS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .program_mode(program_mode),
        .prog_addr(prog_addr),
        .prog_data(prog_data),
        .prog_wr_en(prog_wr_en),
        .start_tick(start_tick),
        .spike(spike),
        .neuron_fire(neuron_fire),
        .monitor_potential(monitor_potential),
        .busy(busy)
    );

    // --- Clock Generation ---
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end


    always @(*) begin
        if (dut.state == 2'd1 && dut.synapse_idx > 0 && dut.synapse_idx <= NUM_INPUTS) begin
            spike = spike_train[dut.synapse_idx - 1];
        end else begin
            spike = 0;
        end
    end


    always @(posedge clk) begin
        // Only print during STATE_PROCESS (2'd1) and when the pipeline has valid data
        if (rst_n && dut.state == 2'd1 && dut.synapse_idx > 0) begin
            $display("    [Time: %6t] SynIdx: %2d | Spike Input: %b | Weight: %3d | Accum Sum (Before Add): %4d",
                     $time,
                     dut.synapse_idx - 1,             
                     spike,                            // The binary spike provided by the testbench
                     dut.weight_from_ram,              // The synaptic weight from BRAM
                     dut.current_sum);                 // The sum *before* this cycle's addition
        end
    end

    // --- Test Stimulus ---
    integer i;
    integer tick_count;
    
    initial begin
        // 1. Initialize Signals
        rst_n = 0;
        program_mode = 0;
        prog_addr = 0;
        prog_data = 0;
        prog_wr_en = 0;
        start_tick = 0;
        spike = 0;
        
        // 2. Setup the "Spike Train" (1s and 0s)
        for (i = 0; i < NUM_INPUTS; i = i + 1) begin
            if (i % 2 == 0) 
                spike_train[i] = 1'b1;
            else 
                spike_train[i] = 1'b0;
        end

        // Wait for reset
        #(CLK_PERIOD * 2);
        rst_n = 1;
        #(CLK_PERIOD * 2);

        $display("\n==============================================");
        $display("--- Starting SNN Simulation (Streaming Version) ---");
        $display("==============================================\n");

        // ==========================================
        // Program the Synaptic Weights
        // ==========================================
        $display("Programming Synaptic Weights to 10...");
        program_mode = 1;
        
        for (i = 0; i < NUM_INPUTS; i = i + 1) begin
            @(posedge clk);
            prog_addr  = i;
            prog_data  = i; // Give every synapse a weight of 10
            prog_wr_en = 1;
        end
        
        @(posedge clk);
        prog_wr_en = 0;
        program_mode = 0; // Exit programming mode
        #(CLK_PERIOD * 2);

        // ==========================================
        // Run Inference Ticks
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

            // Wait until the core finishes processing the 16 streaming spikes
            wait(busy == 0);
            
            // Wait one extra clock cycle to observe the LIF neuron update phase
            @(posedge clk);
            
            $display(">>> TICK %0d COMPLETE <<<", tick_count);
            $display(">>> Final Accumulated Sum sent to Neuron: %0d", dut.current_sum);
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

    // --- Waveform Dump ---
    initial begin
        $dumpfile("snn_wave.vcd");
        $dumpvars(0, tb_snn_core);
    end

endmodule