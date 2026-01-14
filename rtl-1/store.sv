`timescale 1ns / 1ps

module store(
    input store_en,
    input store_rst,
    input clk,
    input [15:0] acc_out,
    output reg [15:0]value
    );
    always @(posedge clk) begin
        if(store_en) begin
            value<=acc_out;
        end
        if(store_rst) begin
            value<=0;
        end
    end
endmodule