// Random Number Generator Module
module xorshift_prng #(
    parameter int WIDTH = 8,                    // How many bits for random number (8 = 0-255)
    parameter logic [WIDTH-1:0] SEED = 8'hA5   // Starting number (can't be zero)
)(
    input  logic clk,                           // Clock signal
    input  logic rst_n,                         // Reset (0=reset, 1=run)
    input  logic enable,                        // Turn on/off (1=on, 0=off)
    output logic [WIDTH-1:0] rnd_out,          // Random number output
    output logic valid                          // Is output ready? (1=yes, 0=no)
);

    logic [WIDTH-1:0] state;                    // Stores current random number
    logic [WIDTH-1:0] y;                        // Temporary variable for math
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= SEED;                      // Start with seed value
            valid <= 1'b0;                     // Output not ready yet
        end else if (enable) begin
            // Make new random number using XORShift math
            y = state ^ (state << 3);           // XOR with left shift 3
            y = y ^ (y >> 5);                   // XOR with right shift 5  
            y = y ^ (y << 1);                   // XOR with left shift 1
            state <= y;                         // Save new random number
            valid <= 1'b1;                     // Output is ready
        end else begin
            valid <= 1'b0;                     // Not ready when disabled
        end
    end
    
    assign rnd_out = state;                     // Output the current random number
endmodule

// Spike Generator Module
module poisson_encoder #(
    parameter int DATA_WIDTH = 8,               // Input size (8 = 0-255)
    parameter int COUNTER_WIDTH = 16,           // Counter size (16 = 0-65535)
    parameter logic [DATA_WIDTH-1:0] RNG_SEED = 8'hA5, // Random seed
    parameter bit ENABLE_STATISTICS = 1'b1     // Count spikes? (1=yes, 0=no)
)(
    input  logic clk,                           // Clock
    input  logic rst_n,                         // Reset
    input  logic enable,                        // On/off switch
    input  logic [DATA_WIDTH-1:0] a,           // Input value (higher = more spikes)
    
    output logic spike_out,                     // Spike output (1=spike, 0=no spike)
    output logic spike_valid,                   // Is spike output ready?
    output logic [COUNTER_WIDTH-1:0] spike_count, // How many spikes total
    output logic [COUNTER_WIDTH-1:0] cycle_count, // How many clock cycles total
    output logic stats_overflow                 // Did counters get too big?
);

    // Internal signals
    logic [DATA_WIDTH-1:0] rnd_val;            // Random number from generator
    logic rnd_valid;                            // Is random number ready?
    logic [DATA_WIDTH-1:0] y;                  // Temporary variable
    logic [COUNTER_WIDTH-1:0] spike_counter;   // Counts spikes
    logic [COUNTER_WIDTH-1:0] cycle_counter;   // Counts clock cycles
    logic stats_overflow_int;                  // Overflow flag

    // Create random number generator
    xorshift_prng #(
        .WIDTH(DATA_WIDTH),
        .SEED(RNG_SEED)
    ) rng_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .rnd_out(rnd_val),
        .valid(rnd_valid)
    );

    // Main spike generation logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset everything to zero
            spike_out <= 1'b0;
            spike_valid <= 1'b0;
            spike_counter <= '0;
            cycle_counter <= '0;
            stats_overflow_int <= 1'b0;
            
        end else if (enable && rnd_valid) begin
            // Generate spikes when enabled and random number is ready
            y = a;                              // Copy input to temp variable
            spike_out <= (rnd_val < y);        // Spike if: random < input
            spike_valid <= 1'b1;               // Mark output as ready
            
            // Count statistics if enabled
            if (ENABLE_STATISTICS) begin
                // Count clock cycles
                if (cycle_counter == {COUNTER_WIDTH{1'b1}}) begin
                    stats_overflow_int <= 1'b1; // Counter full!
                end else begin
                    cycle_counter <= cycle_counter + 1;
                end
                
                // Count spikes
                if ((rnd_val < y) && !stats_overflow_int) begin
                    if (spike_counter == {COUNTER_WIDTH{1'b1}}) begin
                        stats_overflow_int <= 1'b1; // Counter full!
                    end else begin
                        spike_counter <= spike_counter + 1;
                    end
                end
            end
            
        end else begin
            // When disabled, no spikes
            spike_out <= 1'b0;
            spike_valid <= 1'b0;
        end
    end

    // Connect internal signals to outputs
    assign spike_count = spike_counter;
    assign cycle_count = cycle_counter;
    assign stats_overflow = stats_overflow_int;

endmodule

/*
HOW IT WORKS:
1. Input 'a' controls spike rate (0=no spikes, 255=many spikes for 8-bit)
2. Random generator makes random numbers
3. If random_number < input_value, make a spike
4. Higher input = more spikes, but timing is random
5. Counters track how many spikes and clock cycles happened

EXAMPLE:
- If a=0: random is never < 0, so no spikes
- If a=128: random < 128 about half the time, so 50% spike rate  
- If a=255: random < 255 almost always, so ~100% spike rate
*/