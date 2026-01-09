module lif_neuron #(
    parameter THRESHOLD = 16'd1000,
    parameter LEAK_SHIFT = 3
)(
    input wire clk,
    input wire rst_n,
    input wire update_enable,
    input wire signed [15:0] input_sum, 
    output reg fire,
    output reg signed [15:0] potential
);
    
    wire signed [16:0] calc_potential;
    
   
    assign calc_potential = {potential[15], potential} 
                          - {potential[15], (potential >>> LEAK_SHIFT)} 
                          + {input_sum[15], input_sum};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            potential <= 0;
            fire <= 0;
        end else if (update_enable) begin
            if (calc_potential >= $signed({1'b0, THRESHOLD})) begin
                fire <= 1;
                potential <= 0;      // Reset
            end else if (calc_potential < 0) begin
                fire <= 0;
                potential <= 0;     
            end else begin
                fire <= 0;
                potential <= calc_potential[15:0];
            end
        end else begin
            fire <= 0;
        end
    end
endmodule