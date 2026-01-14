module xor_shift_rng (
    input wire clk,
    input wire rst_n,
    output reg [7:0] random_out
);
    reg [31:0] state;
  	reg [31:0] next_state;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 32'd2463534242; // Non-zero seed
            random_out <= 0;
        end else begin
            // 32-bit XOR Shift Algorithm
            
            next_state = state;
            next_state = next_state ^ (next_state << 13);
            next_state = next_state ^ (next_state >> 17);
            next_state = next_state ^ (next_state << 5);
            
            state <= next_state;
            random_out <= next_state[7:0]; // Use lower 8 bits
        end
    end
endmodule









