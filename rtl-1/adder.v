`timescale 1ns / 1ps


module adder(
    input [15:0] and_val,
    input [15:0] decay_val,
    output [15:0] acc_val
    );
    assign acc_val= and_val+decay_val;
endmodule
