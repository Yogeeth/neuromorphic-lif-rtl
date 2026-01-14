`timescale 1ns / 1ps

module mult_reg(
    input mult_en,
    input mult_rst,
    input clk,
    input [15:0] mult_out,
    output reg [15:0]value
    );
    always @(posedge clk) begin
        if(mult_en) begin
            value<=mult_out;
        end
        if(mult_rst) begin
            value<=0;
        end
    end
endmodule
