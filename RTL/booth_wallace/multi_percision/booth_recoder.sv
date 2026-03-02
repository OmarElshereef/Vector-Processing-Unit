// Booth Encoder Module (Radix-4)
module booth_recoder #(
    parameter WIDTH = 64,
    localparam  NUM_PP = (WIDTH/2) + 1
)(
    input  [WIDTH-1:0] multiplier,
    // index is used as an integer index into multiplier; declare as integer
    input  [WIDTH-1:0] mask, // Mask for selecting bits based on vector mode
    input  is_unsigned,  // Control signal: 1 for unsigned, 0 for signed
    output [NUM_PP-2:0] selze,
    output [NUM_PP-2:0] selp1,
    output [NUM_PP-2:0] selp2,
    output [NUM_PP-2:0] seln1,
    output [NUM_PP-2:0] seln2,
    output [7:0] boundary_bits // For handling sign-extension in the last partial product
);
    // Booth Encoder Values:
    // Multiplicand is denoted as M
    // 000: 0
    // 001: +M
    // 010: +M
    // 011: +2M
    // 100: -2M
    // 101: -M
    // 110: -M
    // 111: 0

    generate
        genvar i;
        for (i = 0; i < NUM_PP-1; i = i+1) begin : gen_booth
            // Declare booth_bits per-iteration so each gets its own net
            wire [2:0] booth_bits;
            assign booth_bits[0] = (i*2 == 0) ? 1'b0 : (mask[i*2-1] & multiplier[i*2-1]);
            assign booth_bits[1] = (i*2     < WIDTH) ? multiplier[i*2]   : 1'b0;
            assign booth_bits[2] = (i*2+1   < WIDTH) ? multiplier[i*2+1] : 1'b0;

            // Drive all outputs for every iteration; exactly one will be high
            assign selze[i] = (booth_bits == 3'b000) | (booth_bits == 3'b111); // 0
            assign selp1[i] = (booth_bits == 3'b001) | (booth_bits == 3'b010); // +M
            assign selp2[i] = (booth_bits == 3'b011);                          // +2M
            assign seln2[i] = (booth_bits == 3'b100);                          // -2M
            assign seln1[i] = (booth_bits == 3'b101) | (booth_bits == 3'b110); // -M
        end
    endgenerate

    logic [7:0] boundary_bits_internal;
    logic        booth_bit_0;
    assign boundary_bits = boundary_bits_internal;

    always_comb begin
        for (int j = 1; j < 9; j = j + 1) begin
            booth_bit_0 = ~mask[j*8-1] & multiplier[j*8-1];
            boundary_bits_internal[j-1] = (is_unsigned && booth_bit_0) ? 1'b1 : 1'b0;
        end
    end

endmodule