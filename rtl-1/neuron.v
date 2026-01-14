`timescale 1ns / 1ps

module neuron(
    input spike,
    input spike_valid,
    input clk,
    // Control Inputs
    input acc_en, comp_en, decay_en, mult_en, thresh_en, weight_en, store_en,
    input acc_rst, comp_rst, decay_rst, mult_rst, thresh_rst, weight_rst,  store_rst,
    // Inputs (from Testbench via Top)
    input [15:0] weight_mem, decay_mem, thresh_mem,
    input mux_in,
    // Output
    output result
    );

    // Internal Wires
    wire [15:0] and_in, and_out, decay, mult_val, adder_out, threshold, acc_out;
    wire [15:0] store_out, mux_out; 
    wire [15:0] operand_val; 
    reg latch;
    
    wire comp_out, acc_rst2, comp_regout;
    assign acc_rst2 = comp_regout | acc_rst;
    always @(*) begin
        if(spike_valid) begin
            latch=spike;
        end
    end
    // 1. Weight Reg
    weight_reg a(.clk(clk), .weight_mem(weight_mem), .value(and_in), .weight_rst(weight_rst), .weight_en(weight_en));
    assign and_out = latch ? and_in : 16'd0;

    // 2. Decay Reg
    decay_reg b(.clk(clk), .decay_rst(decay_rst), .decay_en(decay_en), .decay_mem(decay_mem), .value(decay));

    // 3. Store Reg (Feedback)
    store k(.value(store_out), .clk(clk), .store_en(store_en), .store_rst(store_rst), .acc_out(acc_out));

    // 4. Multiplier (Inputs: Decay & Store_Out)
    multiplier c(.decay(decay), .acc_val(store_out), .mult_val(mult_val));

    // 5. Mux (Selects: Store_Out vs Mult_Val)
    mux l(.mux_in(mux_in), .store_out(store_out), .mul_out(mult_val), .mux_out(mux_out));
    
    // 6. Mult Register (After Mux)
    mult_reg d(.clk(clk), .mult_en(mult_en), .mult_rst(mult_rst), .mult_out(mux_out), .value(operand_val));

    // 7. Adder
    adder e(.and_val(and_out), .decay_val(operand_val), .acc_val(adder_out));

    // 8. Accumulator
    accumulator g(.clk(clk), .acc_en(acc_en), .acc_rst(acc_rst2), .adder_out(adder_out), .value(acc_out));

    // 9. Threshold & Compare
    threshold_reg h(.clk(clk), .thresh_en(thresh_en), .thresh_rst(thresh_rst), .thresh_mem(thresh_mem), .value(threshold));
    comparator f(.thresh_reg(threshold), .acc_reg(acc_out), .val(comp_out));
    comparison_reg i(.clk(clk), .comp_en(comp_en), .comp_rst(comp_rst), .value(comp_regout), .comp_out(comp_out));

    assign result = comp_regout;

endmodule