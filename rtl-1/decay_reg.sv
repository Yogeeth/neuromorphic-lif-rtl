`timescale 1ns / 1ps
module decay_reg(
    input decay_en,
    input decay_rst,
    input clk,
    input [15:0] decay_mem,
    output reg [15:0]value
    );
    always @(posedge clk) begin
        if(decay_en) begin
            value<=decay_mem;
        end
        if(decay_rst) begin
            value<=0;
        end
    end
endmodule
