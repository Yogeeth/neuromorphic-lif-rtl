`timescale 1ns / 1ps

module lif_neuron (
    input wire aclk,
    input wire aresetn,

    // AXI-Stream Slave (Receives MAC results from stochastic_mac)
    input wire [31:0]  s_axis_tdata,
    input wire         s_axis_tvalid,
    output wire        s_axis_tready,
    input wire         s_axis_tlast,

    // AXI-Stream Master (Sends 8-bit spike train back to DMA)
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input wire         m_axis_tready,
    output wire        m_axis_tlast
);

    // -- Parameters & States --
    localparam MAX_TIMESTAMPS = 20;
    localparam STATE_INTEGRATE = 1'b0;
    localparam STATE_SEND      = 1'b1;
    
    reg state;

    // -- Internal Registers --
    reg signed [31:0] potential;
    reg [2:0]         ts_count;      // Counts from 0 to 7 (8 timestamps)
    reg [7:0]         spike_train;   // 8-bit shift register for spikes

    // -- Combinatorial Math --
    // We calculate the math BEFORE the clock ticks so we can check the threshold
    wire signed [31:0] leaked_potential;
    wire signed [31:0] integrated_potential;

    // 1. Apply the leak (divide by 8)
    assign leaked_potential = potential - (potential >>> 3);
    // 2. Add the incoming MAC value
    assign integrated_potential = leaked_potential + $signed(s_axis_tdata);

    // -- AXI-Stream Assignments --
    assign s_axis_tready = (state == STATE_INTEGRATE);
    assign m_axis_tvalid = (state == STATE_SEND);
    
    // We send back 32 bits, but only the bottom 8 bits contain our spike train
    assign m_axis_tdata  = {24'd0, spike_train}; 
    assign m_axis_tlast  = 1'b1;

    // -- Core Logic --
    always @(posedge aclk) begin
        if (!aresetn) begin
            state       <= STATE_INTEGRATE;
            potential   <= 32'sd0;
            ts_count    <= 3'd0;
            spike_train <= 8'd0;
        end else begin
            case (state)
                STATE_INTEGRATE: begin
                    if (s_axis_tvalid && s_axis_tready) begin
                        
                        // -- THRESHOLD & SPIKE LOGIC --
                        if (integrated_potential > 255) begin
                            // SPIKE! Subtract 255 (Soft Reset) and shift a '1' into the train
                            potential   <= integrated_potential - 255;
                            spike_train <= {spike_train[6:0], 1'b1}; 
                        end else begin
                            // NO SPIKE! Keep potential and shift a '0' into the train
                            potential   <= integrated_potential;
                            spike_train <= {spike_train[6:0], 1'b0}; 
                        end

                        // -- TIMESTEP TRACKING --
                        if (ts_count == MAX_TIMESTAMPS - 1) begin
                            state    <= STATE_SEND;
                            ts_count <= 3'd0;
                        end else begin
                            ts_count <= ts_count + 1;
                        end
                    end
                end

                STATE_SEND: begin
                // Inside STATE_SEND
                    if (m_axis_tvalid && m_axis_tready) begin
                        state <= STATE_INTEGRATE;
                        potential <= 32'sd0; // Flush the neuron for the next image!
                    end 
                end
            endcase
        end
    end

endmodule