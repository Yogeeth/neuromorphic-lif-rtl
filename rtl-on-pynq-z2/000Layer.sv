`timescale 1ns / 1ps
// =============================================================================
//  snn_layer - 10-neuron SNN layer (pure Verilog-2001, no SystemVerilog)
//
//  Data flow:
//    DMA --> [broadcast] --> MAC[0..9] --> LIF[0..9] --> [serialize] --> DMA
//
//  PS sends 8 batches of 784 pixels; after batch 8 the serializer sends
//  10 x 32-bit words back to DMA (neuron 0 first, neuron 9 last).
//  Requires: weight_0.mem .. weight_9.mem at synthesis time.
// =============================================================================
module layer (
    input  wire        aclk,
    input  wire        aresetn,
    // AXI-Stream Slave  - pixel stream in (broadcast to all 10 MACs)
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,
    // AXI-Stream Master - 10 spike trains serialized out (10 words per frame)
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast
);
    localparam NUM_NEURONS = 10;


    //  Inter-module wires

    // MAC slave tready outputs (AND'd to form top-level tready)
    wire [9:0] mac_s_tready;

    // MAC master -> LIF slave  (one bundle per neuron)
    wire [31:0] mac_m_tdata_0, mac_m_tdata_1, mac_m_tdata_2, mac_m_tdata_3,
                mac_m_tdata_4, mac_m_tdata_5, mac_m_tdata_6, mac_m_tdata_7,
                mac_m_tdata_8, mac_m_tdata_9;
    wire [9:0]  mac_m_tvalid, mac_m_tready, mac_m_tlast;

    // LIF master -> serializer  (one bundle per neuron)
    wire [31:0] lif_m_tdata_0, lif_m_tdata_1, lif_m_tdata_2, lif_m_tdata_3,
                lif_m_tdata_4, lif_m_tdata_5, lif_m_tdata_6, lif_m_tdata_7,
                lif_m_tdata_8, lif_m_tdata_9;
    wire [9:0]  lif_m_tvalid, lif_m_tready, lif_m_tlast;


    //  Input fan-out - all MACs always in same state, AND is safe

    assign s_axis_tready = &mac_s_tready;


    //  10 x (stochastic_mac + lif_neuron) - explicit instantiation


    // --- Neuron 0 ---
    stochastic_mac #(.ROM_FILE("weight_0.mem"), .LFSR_SEED(8'hFF)) u_mac_0 (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(mac_s_tready[0]), .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(mac_m_tdata_0), .m_axis_tvalid(mac_m_tvalid[0]),
        .m_axis_tready(mac_m_tready[0]), .m_axis_tlast(mac_m_tlast[0]));
    lif_neuron u_lif_0 (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(mac_m_tdata_0), .s_axis_tvalid(mac_m_tvalid[0]),
        .s_axis_tready(mac_m_tready[0]), .s_axis_tlast(mac_m_tlast[0]),
        .m_axis_tdata(lif_m_tdata_0), .m_axis_tvalid(lif_m_tvalid[0]),
        .m_axis_tready(lif_m_tready[0]), .m_axis_tlast(lif_m_tlast[0]));

    // --- Neuron 1 ---
    stochastic_mac #(.ROM_FILE("weight_1.mem"), .LFSR_SEED(8'hFE)) u_mac_1 (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(mac_s_tready[1]), .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(mac_m_tdata_1), .m_axis_tvalid(mac_m_tvalid[1]),
        .m_axis_tready(mac_m_tready[1]), .m_axis_tlast(mac_m_tlast[1]));
    lif_neuron u_lif_1 (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(mac_m_tdata_1), .s_axis_tvalid(mac_m_tvalid[1]),
        .s_axis_tready(mac_m_tready[1]), .s_axis_tlast(mac_m_tlast[1]),
        .m_axis_tdata(lif_m_tdata_1), .m_axis_tvalid(lif_m_tvalid[1]),
        .m_axis_tready(lif_m_tready[1]), .m_axis_tlast(lif_m_tlast[1]));

    // --- Neuron 2 ---
    stochastic_mac #(.ROM_FILE("weight_2.mem"), .LFSR_SEED(8'hFD)) u_mac_2 (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(mac_s_tready[2]), .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(mac_m_tdata_2), .m_axis_tvalid(mac_m_tvalid[2]),
        .m_axis_tready(mac_m_tready[2]), .m_axis_tlast(mac_m_tlast[2]));
    lif_neuron u_lif_2 (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(mac_m_tdata_2), .s_axis_tvalid(mac_m_tvalid[2]),
        .s_axis_tready(mac_m_tready[2]), .s_axis_tlast(mac_m_tlast[2]),
        .m_axis_tdata(lif_m_tdata_2), .m_axis_tvalid(lif_m_tvalid[2]),
        .m_axis_tready(lif_m_tready[2]), .m_axis_tlast(lif_m_tlast[2]));

    // --- Neuron 3 ---
    stochastic_mac #(.ROM_FILE("weight_3.mem"), .LFSR_SEED(8'hFC)) u_mac_3 (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(mac_s_tready[3]), .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(mac_m_tdata_3), .m_axis_tvalid(mac_m_tvalid[3]),
        .m_axis_tready(mac_m_tready[3]), .m_axis_tlast(mac_m_tlast[3]));
    lif_neuron u_lif_3 (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(mac_m_tdata_3), .s_axis_tvalid(mac_m_tvalid[3]),
        .s_axis_tready(mac_m_tready[3]), .s_axis_tlast(mac_m_tlast[3]),
        .m_axis_tdata(lif_m_tdata_3), .m_axis_tvalid(lif_m_tvalid[3]),
        .m_axis_tready(lif_m_tready[3]), .m_axis_tlast(lif_m_tlast[3]));

    // --- Neuron 4 ---
    stochastic_mac #(.ROM_FILE("weight_4.mem"), .LFSR_SEED(8'hFB)) u_mac_4 (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(mac_s_tready[4]), .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(mac_m_tdata_4), .m_axis_tvalid(mac_m_tvalid[4]),
        .m_axis_tready(mac_m_tready[4]), .m_axis_tlast(mac_m_tlast[4]));
    lif_neuron u_lif_4 (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(mac_m_tdata_4), .s_axis_tvalid(mac_m_tvalid[4]),
        .s_axis_tready(mac_m_tready[4]), .s_axis_tlast(mac_m_tlast[4]),
        .m_axis_tdata(lif_m_tdata_4), .m_axis_tvalid(lif_m_tvalid[4]),
        .m_axis_tready(lif_m_tready[4]), .m_axis_tlast(lif_m_tlast[4]));

    // --- Neuron 5 ---
    stochastic_mac #(.ROM_FILE("weight_5.mem"), .LFSR_SEED(8'hFA)) u_mac_5 (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(mac_s_tready[5]), .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(mac_m_tdata_5), .m_axis_tvalid(mac_m_tvalid[5]),
        .m_axis_tready(mac_m_tready[5]), .m_axis_tlast(mac_m_tlast[5]));
    lif_neuron u_lif_5 (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(mac_m_tdata_5), .s_axis_tvalid(mac_m_tvalid[5]),
        .s_axis_tready(mac_m_tready[5]), .s_axis_tlast(mac_m_tlast[5]),
        .m_axis_tdata(lif_m_tdata_5), .m_axis_tvalid(lif_m_tvalid[5]),
        .m_axis_tready(lif_m_tready[5]), .m_axis_tlast(lif_m_tlast[5]));

    // --- Neuron 6 ---
    stochastic_mac #(.ROM_FILE("weight_6.mem"), .LFSR_SEED(8'hF9)) u_mac_6 (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(mac_s_tready[6]), .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(mac_m_tdata_6), .m_axis_tvalid(mac_m_tvalid[6]),
        .m_axis_tready(mac_m_tready[6]), .m_axis_tlast(mac_m_tlast[6]));
    lif_neuron u_lif_6 (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(mac_m_tdata_6), .s_axis_tvalid(mac_m_tvalid[6]),
        .s_axis_tready(mac_m_tready[6]), .s_axis_tlast(mac_m_tlast[6]),
        .m_axis_tdata(lif_m_tdata_6), .m_axis_tvalid(lif_m_tvalid[6]),
        .m_axis_tready(lif_m_tready[6]), .m_axis_tlast(lif_m_tlast[6]));

    // --- Neuron 7 ---
    stochastic_mac #(.ROM_FILE("weight_7.mem"), .LFSR_SEED(8'hF8)) u_mac_7 (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(mac_s_tready[7]), .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(mac_m_tdata_7), .m_axis_tvalid(mac_m_tvalid[7]),
        .m_axis_tready(mac_m_tready[7]), .m_axis_tlast(mac_m_tlast[7]));
    lif_neuron u_lif_7 (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(mac_m_tdata_7), .s_axis_tvalid(mac_m_tvalid[7]),
        .s_axis_tready(mac_m_tready[7]), .s_axis_tlast(mac_m_tlast[7]),
        .m_axis_tdata(lif_m_tdata_7), .m_axis_tvalid(lif_m_tvalid[7]),
        .m_axis_tready(lif_m_tready[7]), .m_axis_tlast(lif_m_tlast[7]));

    // --- Neuron 8 ---
    stochastic_mac #(.ROM_FILE("weight_8.mem"), .LFSR_SEED(8'hF7)) u_mac_8 (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(mac_s_tready[8]), .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(mac_m_tdata_8), .m_axis_tvalid(mac_m_tvalid[8]),
        .m_axis_tready(mac_m_tready[8]), .m_axis_tlast(mac_m_tlast[8]));
    lif_neuron u_lif_8 (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(mac_m_tdata_8), .s_axis_tvalid(mac_m_tvalid[8]),
        .s_axis_tready(mac_m_tready[8]), .s_axis_tlast(mac_m_tlast[8]),
        .m_axis_tdata(lif_m_tdata_8), .m_axis_tvalid(lif_m_tvalid[8]),
        .m_axis_tready(lif_m_tready[8]), .m_axis_tlast(lif_m_tlast[8]));

    // --- Neuron 9 ---
    stochastic_mac #(.ROM_FILE("weight_9.mem"), .LFSR_SEED(8'hF6)) u_mac_9 (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(mac_s_tready[9]), .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(mac_m_tdata_9), .m_axis_tvalid(mac_m_tvalid[9]),
        .m_axis_tready(mac_m_tready[9]), .m_axis_tlast(mac_m_tlast[9]));
    lif_neuron u_lif_9 (
        .aclk(aclk), .aresetn(aresetn),
        .s_axis_tdata(mac_m_tdata_9), .s_axis_tvalid(mac_m_tvalid[9]),
        .s_axis_tready(mac_m_tready[9]), .s_axis_tlast(mac_m_tlast[9]),
        .m_axis_tdata(lif_m_tdata_9), .m_axis_tvalid(lif_m_tvalid[9]),
        .m_axis_tready(lif_m_tready[9]), .m_axis_tlast(lif_m_tlast[9]));


    //  Output MUX - routes selected LIF data to DMA output ports

    reg [31:0] mux_tdata;
    reg        mux_tvalid;

    always @(*) begin
        case (send_idx)
            4'd0: begin mux_tdata = lif_m_tdata_0; mux_tvalid = lif_m_tvalid[0]; end
            4'd1: begin mux_tdata = lif_m_tdata_1; mux_tvalid = lif_m_tvalid[1]; end
            4'd2: begin mux_tdata = lif_m_tdata_2; mux_tvalid = lif_m_tvalid[2]; end
            4'd3: begin mux_tdata = lif_m_tdata_3; mux_tvalid = lif_m_tvalid[3]; end
            4'd4: begin mux_tdata = lif_m_tdata_4; mux_tvalid = lif_m_tvalid[4]; end
            4'd5: begin mux_tdata = lif_m_tdata_5; mux_tvalid = lif_m_tvalid[5]; end
            4'd6: begin mux_tdata = lif_m_tdata_6; mux_tvalid = lif_m_tvalid[6]; end
            4'd7: begin mux_tdata = lif_m_tdata_7; mux_tvalid = lif_m_tvalid[7]; end
            4'd8: begin mux_tdata = lif_m_tdata_8; mux_tvalid = lif_m_tvalid[8]; end
            4'd9: begin mux_tdata = lif_m_tdata_9; mux_tvalid = lif_m_tvalid[9]; end
            default: begin mux_tdata = 32'd0; mux_tvalid = 1'b0; end
        endcase
    end

    assign m_axis_tdata  = mux_tdata;
    assign m_axis_tvalid = sending & mux_tvalid;
    assign m_axis_tlast  = sending & (send_idx == 4'd9);

    // lif_m_tready - assert only to the currently selected LIF
    assign lif_m_tready[0] = sending & (send_idx == 4'd0) & m_axis_tready;
    assign lif_m_tready[1] = sending & (send_idx == 4'd1) & m_axis_tready;
    assign lif_m_tready[2] = sending & (send_idx == 4'd2) & m_axis_tready;
    assign lif_m_tready[3] = sending & (send_idx == 4'd3) & m_axis_tready;
    assign lif_m_tready[4] = sending & (send_idx == 4'd4) & m_axis_tready;
    assign lif_m_tready[5] = sending & (send_idx == 4'd5) & m_axis_tready;
    assign lif_m_tready[6] = sending & (send_idx == 4'd6) & m_axis_tready;
    assign lif_m_tready[7] = sending & (send_idx == 4'd7) & m_axis_tready;
    assign lif_m_tready[8] = sending & (send_idx == 4'd8) & m_axis_tready;
    assign lif_m_tready[9] = sending & (send_idx == 4'd9) & m_axis_tready;


    //  Output Serializer state machine

    reg       sending;
    reg [3:0] send_idx;

    always @(posedge aclk) begin
        if (!aresetn) begin
            sending  <= 1'b0;
            send_idx <= 4'd0;
        end else begin
            if (!sending) begin
                // Start when ALL 10 LIFs have data (they always finish together)
                if (&lif_m_tvalid) begin
                    sending  <= 1'b1;
                    send_idx <= 4'd0;
                end
            end else begin
                // Advance on each successful DMA handshake
                if (m_axis_tready && mux_tvalid) begin
                    if (send_idx == 4'd9) begin
                        sending  <= 1'b0;
                        send_idx <= 4'd0;
                    end else begin
                        send_idx <= send_idx + 1'b1;
                    end
                end
            end
        end
    end

endmodule
