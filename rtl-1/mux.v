`timescale 1ns / 1ps

module mux(
    input [15:0] store_out,
    input [15:0] mul_out,
    input mux_in,
    output [15:0] mux_out
    );
    assign mux_out= mux_in?store_out:store_out>>1;
endmodule
