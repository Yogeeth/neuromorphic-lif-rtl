`timescale 1ns / 1ps
module accumulator(
    input acc_en,
    input acc_rst,
    input clk,
    input [15:0] adder_out,
    output reg [15:0]value
    );
    always @(posedge clk) begin
        if(acc_en) begin
            value<=adder_out;
        end
        if(acc_rst) begin
            value<=0;
        end
    end
endmodule


