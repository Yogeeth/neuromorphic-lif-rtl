`timescale 1ns / 1ps

module controller(
    input spike_valid,
    input calc_en,
    input rst,
    input clk,
    input comp_out, // Feedback
    output reg acc_en, comp_en, decay_en, mult_en, thresh_en, weight_en, spike_en, store_en,
    output reg acc_rst, comp_rst, decay_rst, mult_rst, thresh_rst, weight_rst, spike_rst, store_rst,
    output reg data_valid,
    output reg mux_in
    );
    parameter S0=0,S1=1,S2=2,S3=3,S4=4,S5=5,S6=6,S7=7;
    reg [2:0] ps,ns;
    reg [12:0] counter; // Increased width for 784

    always @(*) begin
        case(ps)
        S0:begin
            acc_en=0; comp_en=0; decay_en=0; store_en=0; mult_en=0;
            thresh_en=0; weight_en=0; spike_en=0;
            acc_rst=0; comp_rst=0; decay_rst=0; store_rst=0; mult_rst=0;
            thresh_rst=0; weight_rst=0; spike_rst=0;
            data_valid=0;
        end
        S1: begin
            acc_en=0; comp_en=0; decay_en=1; store_en=1; mult_en=0;
            thresh_en=1; weight_en=1; spike_en=1;
            acc_rst=0; comp_rst=0; decay_rst=0; store_rst=0; mult_rst=0;
            thresh_rst=0; weight_rst=0; spike_rst=0;
            data_valid=0;
        end
        S2: begin
            acc_en=0; comp_en=0; decay_en=0; store_en=0; mult_en=1;
            thresh_en=0; weight_en=0; spike_en=0;
            acc_rst=0; comp_rst=0; decay_rst=0; store_rst=0; mult_rst=0;
            thresh_rst=0; weight_rst=0; spike_rst=0;
            data_valid=0;
        end
        S3: begin
            acc_en=1; comp_en=0; decay_en=0; store_en=0; mult_en=0;
            thresh_en=0; weight_en=0; spike_en=0;
            acc_rst=0; comp_rst=0; decay_rst=0; store_rst=0; mult_rst=0;
            thresh_rst=0; weight_rst=0; spike_rst=0;
            data_valid=0;
        end
        S4: begin
            acc_en=0; comp_en=1; decay_en=0; store_en=0; mult_en=0;
            thresh_en=0; weight_en=0; spike_en=0;
            acc_rst=0; comp_rst=0; decay_rst=0; store_rst=0; mult_rst=0;
            thresh_rst=0; weight_rst=0; spike_rst=0;
            data_valid=0;
        end
        S5: begin
            acc_en=0; comp_en=0; decay_en=0; store_en=0; mult_en=0;
            thresh_en=0; weight_en=0; spike_en=0;
            acc_rst=0; comp_rst=1; decay_rst=1; store_rst=0; mult_rst=1;
            thresh_rst=1; weight_rst=1; spike_rst=1;
            data_valid=1;
        end
        S6: begin
            acc_en=0; comp_en=0; decay_en=0; store_en=0; mult_en=0;
            thresh_en=0; weight_en=0; spike_en=0;
            acc_rst=1; comp_rst=1; decay_rst=1; store_rst=0; mult_rst=1;
            thresh_rst=1; weight_rst=1; spike_rst=1;
            data_valid=0;
        end
        endcase
    end

    always @(*) begin
        case(ps)
        S0:ns=rst?S6:((calc_en)?S1:S0);
        S1:ns=rst?S6:((spike_valid)?S2:S1);
        S2:ns=rst?S6:S3;
        S3:ns=rst?S6:S4;
        S4:ns=rst?S6:S5;
        S5:ns=rst?S6:S0;
        S6:ns=S0;
        default: ns=S0;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ps <= S6;
            counter <= 0;
            data_valid <= 0;
            mux_in <= 1; // Start with Decay enabled (or logic 1) on reset
        end 
        else begin
            ps <= ns;
            
            // --- 1. Robust Counter Update Logic ---
            // Update counter only in state S5 (End of processing step)
            if(ps == S5) begin
                if(counter == 783 || comp_out == 1) begin
                    counter <= 0;      // Reset if finished or fired
                end else begin
                    counter <= counter + 1; // Otherwise increment
                end
            end
            
            // --- 2. Mux Control Logic ---
            // "Enable mux_in once all pixels are finished"
            // When counter is 0 (Start of new image), set mux_in = 1 (Decay path).
            // For all other pixels (1 to 783), set mux_in = 0 (Integrate path).
            if (counter == 0) 
                mux_in <= 0;
            else 
                mux_in <= 1;
        end
    end
endmodule