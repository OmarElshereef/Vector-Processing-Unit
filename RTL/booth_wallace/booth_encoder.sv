// Booth Encoder Module (Radix-4)
module booth_encoder #(
    parameter WIDTH = 16
)(
    input  [WIDTH-1:0] multiplicand,
    input  [WIDTH-1:0] multiplier,
    // index is used as an integer index into multiplier; declare as integer
    input  integer index,
    output [2*WIDTH-1:0] partial_product
);

    wire [2:0] booth_bits;
    wire [WIDTH+1:0] multiplicand_ext;
    wire [2*WIDTH-1:0] encoded_value;
    
    // Extract 3 bits for Booth encoding (including previous bit)
    assign booth_bits[0] = (index*2 == 0) ? 1'b0 : multiplier[index*2-1];
    assign booth_bits[1] = (index*2 < WIDTH) ? multiplier[index*2] : 1'b0;
    assign booth_bits[2] = (index*2+1 < WIDTH) ? multiplier[index*2+1] : 1'b0;
    
    // Sign-extend multiplicand
    assign multiplicand_ext = {multiplicand[WIDTH-1],multiplicand[WIDTH-1], multiplicand};
    
    // Booth encoding logic
    wire negate, double;
    assign negate = booth_bits[2];
    assign double = (booth_bits[1:0] == 2'b00 || booth_bits[1:0] == 2'b11);
    
    wire [WIDTH+1:0] shifted_mult;
    assign shifted_mult = double ? (multiplicand_ext << 1) : multiplicand_ext;
    
    wire [WIDTH+1:0] encoded;
    assign encoded = negate ? (~shifted_mult + 1'b1) : shifted_mult;
    
    // Determine if we use the value based on booth bits
    wire use_value;
    assign use_value = (booth_bits != 3'b000) && (booth_bits != 3'b111);
    
    // Shift and sign-extend the encoded value
    wire [2*WIDTH-1:0] extended;
    assign extended = {{(WIDTH-2){encoded[WIDTH+1]}}, encoded};
    assign encoded_value = use_value ? (extended << (index*2)) : {2*WIDTH{1'b0}};
    
    assign partial_product = encoded_value;

endmodule