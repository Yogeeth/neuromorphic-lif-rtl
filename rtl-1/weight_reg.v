`timescale 1ns / 1ps


module weight_reg(
    input weight_en,
    input weight_rst,
    input clk,
    input [15:0] weight_mem,
    output reg [15:0]value
    );
    always @(posedge clk) begin
        if(weight_en) begin
            value<=weight_mem;
        end
        if(weight_rst) begin
            value<=0;
        end
    end
endmodule
