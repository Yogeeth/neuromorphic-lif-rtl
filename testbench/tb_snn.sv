`timescale 1ns/1ps

module tb_snn_simple;

    // --- Signals ---
    logic clk = 0;
    logic rst_n = 0;
    logic [7:0] current_input_val;
    wire [7:0] input_read_addr;
    wire neuron_fire;
    wire busy;
    
    // Programming signals
    logic program_mode = 0;
    logic [7:0] prog_addr = 0;
    logic signed [7:0] prog_data = 0;
    logic prog_wr_en = 0;
    logic start_tick = 0;


    int step_count = 0;


    snn_core #(.NUM_INPUTS(256)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .program_mode(program_mode),
        .prog_addr(prog_addr),
        .prog_data(prog_data),
        .prog_wr_en(prog_wr_en),
        .start_tick(start_tick),
        .current_input_val(current_input_val),
        .input_read_addr(input_read_addr),
        .neuron_fire(neuron_fire),
        .monitor_potential(),
        .busy(busy)
    );


    always #5 clk = ~clk;

    always @(input_read_addr) current_input_val = 128;
    always @(posedge neuron_fire) begin
      $display(">>> NEURON FIRED at Step %0d (Time: %0t) | Bucket : %0d", step_count, $time,dut.neuron_inst.potential);
    end
  
  always @(posedge clk) begin
        
    $display("Time: %0t | Step: %0d | Synapse Index: %0d | Accumulator: %0d | Bucket : %0d", 
                     $time, step_count, dut.synapse_idx, dut.current_sum,dut.neuron_inst.potential);
      
    end


    initial begin
        $dumpfile("snn_simple.vcd");
        $dumpvars(0, tb_snn_simple);

        // 1. Reset
        #50 rst_n = 1;
        #20;

        // 2. Program Weights (Set all to 2)
        program_mode = 1;
        for (int i=0; i<256; i++) begin
            prog_addr = i;
            prog_data = 2; 
            prog_wr_en = 1;
            @(posedge clk);
        end
        prog_wr_en = 0;
        program_mode = 0;
        @(posedge clk);

        

        // 3. Run 50 Inference Steps
        for (step_count = 0; step_count < 50; step_count++) begin
            
           
            start_tick = 1;
            @(posedge clk);
            start_tick = 0;

            
            wait(busy == 0);
            
           
            repeat(5) @(posedge clk);
        end

       
        $finish;
    end

endmodule