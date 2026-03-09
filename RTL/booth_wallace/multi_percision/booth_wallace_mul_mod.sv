// -----------------------------------------------------------------------------
//  booth_wallace_mul_mod  –  Top-level combined multiplier
// -----------------------------------------------------------------------------
module booth_wallace_mul_mod #(
    parameter WIDTH   = 64,
    localparam NUM_PP = (WIDTH/2) + 1
)(
    input  [WIDTH-1:0]   multiplier,
    input  [WIDTH-1:0]   multiplicand,
    input  [1:0]         vector_mode,   // 0:8b  1:16b  2:32b  3:64b
    input                is_unsigned,
    output [2*WIDTH-1:0] result
);

    wire [2*WIDTH-1:0] PPs [0:NUM_PP-1];

    booth_encoder_mod #(
        .WIDTH (WIDTH)
    ) u_encoder (
        .multiplier   (multiplier),
        .multiplicand (multiplicand),
        .vector_mode  (vector_mode),
        .is_unsigned  (is_unsigned),
        .PPs          (PPs)
    );

    wallace_tree_mod #(
        .WIDTH      (2*WIDTH),
        .NUM_INPUTS (NUM_PP)
    ) u_wallace (
        .inputs      (PPs),
        .vector_mode (vector_mode),
        .sum         (result)
    );

endmodule
