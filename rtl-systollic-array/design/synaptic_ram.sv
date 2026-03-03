module synaptic_ram #(
    parameter NUM_SYNAPSES = 256,
    parameter WEIGHT_WIDTH = 8
)(
    input wire clk,
    input wire write_enable,
    input wire [$clog2(NUM_SYNAPSES)-1:0] address,
    input wire signed [WEIGHT_WIDTH-1:0] data_in,
    output reg signed [WEIGHT_WIDTH-1:0] weight_out // Now a reg for synchronous read
);
    reg signed [WEIGHT_WIDTH-1:0] memory [0:NUM_SYNAPSES-1];


    always @(posedge clk) begin
        if (write_enable) begin
            memory[address] <= data_in;
        end
        weight_out <= memory[address]; 
    end
endmodule