`timescale 1ns / 1ps


module comparator(
    input [15:0] thresh_reg,
    input [15:0] acc_reg,
    output val
    );
    assign val=acc_reg >= thresh_reg;
endmodule
