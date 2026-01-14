`timescale 1ns / 1ps
module comparison_reg(
    input comp_en,
    input comp_rst,
    input clk,
    input comp_out,
    output reg value
    );
    always @(posedge clk) begin
        if(comp_en) begin
            value<=comp_out;
        end
        if(comp_rst) begin
            value<=0;
        end
    end
endmodule

