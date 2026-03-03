module xor_shift_rng (
    input wire clk,
    input wire rst_n,
    output reg [7:0] random_out
);
    reg [31:0] state;
    

    wire [31:0] shift1 = state ^ (state << 13);
    wire [31:0] shift2 = shift1 ^ (shift1 >> 17);
    wire [31:0] shift3 = shift2 ^ (shift2 << 5);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 32'd2463534242; // Non-zero seed
            random_out <= 0;
        end else begin
            state <= shift3;
            random_out <= shift3[7:0]; // Use lower 8 bits
        end
    end
endmodule