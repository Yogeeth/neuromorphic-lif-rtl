`timescale 1ns / 1ps
module threshold_reg(
    input thresh_en,
    input thresh_rst,
    input clk,
    input [15:0]thresh_mem,
    output reg [15:0]value
    );
    always @(posedge clk) begin
        if(thresh_en) begin
            value<=thresh_mem;
        end
        if(thresh_rst) begin
            value<=0;
        end
    end
endmodule
