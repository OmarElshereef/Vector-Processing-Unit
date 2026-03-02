// Parameterized Booth-Wallace Tree Multiplier
// Uses Radix-4 Modified Booth Encoding + Wallace Tree reduction

module booth_wallace_multiplier #(
    parameter WIDTH = 64
)(
    input  [WIDTH-1:0] multiplicand,
    input  [WIDTH-1:0] multiplier,
    input  is_unsigned,  // Control signal: 1 for unsigned, 0 for signed
    output [2*WIDTH-1:0] product
);

    // Number of partial products after Booth encoding
    localparam NUM_PP = (WIDTH/2) + 1;
    
    // Partial products array
    wire [2*WIDTH-1:0] partial_products [0:NUM_PP-1];

    // Generate partial products using Booth encoding
    genvar i;
    generate
        for (i = 0; i < NUM_PP; i = i + 1) begin : booth_encoder
            booth_encoder #(.WIDTH(WIDTH)) booth_enc (
                .multiplicand(multiplicand),
                .multiplier(multiplier),
                .index(i),
                .is_unsigned(is_unsigned),
                .partial_product(partial_products[i])
            );
        end
    endgenerate

    // Wallace tree reduction
    wallace_tree #(
        .WIDTH(2*WIDTH),
        .NUM_INPUTS(NUM_PP)
    ) wallace (
        .inputs(partial_products),
        .is_unsigned(is_unsigned),
        .sum(product)
    );

endmodule