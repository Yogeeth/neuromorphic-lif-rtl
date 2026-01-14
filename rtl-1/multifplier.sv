`timescale 1ns / 1ps


module multiplier(
    input [15:0] decay,
    input [15:0] acc_val,
    output [15:0] mult_val
    );
    assign mult_val= decay* acc_val;
endmodule
