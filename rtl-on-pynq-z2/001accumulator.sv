`timescale 1ns / 1ps

module stochastic_mac #(
    // Parameters 
    parameter ROM_FILE = "weight_0.mem", 
    parameter LFSR_SEED = 8'hFF
) (
    input wire aclk,
    input wire aresetn,

    // AXI-Stream Slave (Receives pixels from PS via DMA)
    input wire [31:0]  s_axis_tdata,
    input wire         s_axis_tvalid,
    output wire        s_axis_tready,
    input wire         s_axis_tlast,

    // AXI-Stream Master (Sends result back to PS via DMA)
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input wire         m_axis_tready,
    output wire        m_axis_tlast
);

    // Parameters & State Machine
    localparam NUM_PIXELS = 784;
    localparam STATE_RECV = 1'b0;
    localparam STATE_SEND = 1'b1;
    
    reg state;

    // Internal Registers
    // ADDED 'signed' to accumulator to support negative neural network weights
    reg signed [31:0] accumulator;
    reg [9:0]  pixel_count;
    reg [7:0]  lfsr;

    // Weight ROM Inference
    // ADDED 'signed' to properly interpret hex values as negative numbers if MSB is 1
    wire signed [15:0] weight_val;
    reg  signed [15:0] weight_rom [0:783];

    // Initialize ROM with custom weights from file (Must be inside initial block)
    initial begin
        $readmemh(ROM_FILE, weight_rom);
    end
    
    // Read from ROM combinatorially based on current pixel count
    assign weight_val = weight_rom[pixel_count];

    // -- LFSR Logic (8-bit pseudo-random generator) --
    // Polynomial: x^8 + x^6 + x^5 + x^4 + 1
    wire lfsr_feedback = lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3];

    // -- AXI-Stream Assignments --
    assign s_axis_tready = (state == STATE_RECV);
    assign m_axis_tvalid = (state == STATE_SEND);
    assign m_axis_tlast  = 1'b1;         // We only send 1 piece of data back
    assign m_axis_tdata  = accumulator;

    // -- Core Logic --
    always @(posedge aclk) begin
        if (!aresetn) begin
            state       <= STATE_RECV;
            accumulator <= 32'sd0; // Signed zero
            pixel_count <= 10'd0;
            lfsr        <= LFSR_SEED;  // Seed must be non-zero
        end else begin
            case (state)
                STATE_RECV: begin
                    if (s_axis_tvalid && s_axis_tready) begin
                        // 1. Shift LFSR to generate new random number
                        lfsr <= {lfsr[6:0], lfsr_feedback};

                        // 2. Compare Pixel Value >= Random Number
                        // FIXED: This ensures an input of 0 has a 0% chance of adding the weight
                        if (s_axis_tdata[7:0] >= lfsr) begin
                            accumulator <= accumulator + weight_val;
                        end

                        // 3. Track pixels and transition state
                        if (pixel_count == NUM_PIXELS - 1 || s_axis_tlast) begin
                            pixel_count <= 0;
                            state       <= STATE_SEND;
                        end else begin
                            pixel_count <= pixel_count + 1;
                        end
                    end
                end

                STATE_SEND: begin
                    // Wait for DMA to accept our accumulated result
                    if (m_axis_tready && m_axis_tvalid) begin
                        state       <= STATE_RECV;
                        accumulator <= 32'sd0; // Reset for the next 784-pixel batch
                    end
                end
            endcase
        end
    end

endmodule