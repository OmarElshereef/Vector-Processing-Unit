
module booth_encoder_mod #(
    parameter WIDTH =64,
    localparam NUM_PP = (WIDTH/2) + 1
) (
    input  [WIDTH-1:0] multiplier,
    input  [WIDTH-1:0] multiplicand,
    input  [1:0] vector_mode,
    input  is_unsigned,
    output [2*WIDTH-1:0] PPs [0:NUM_PP-1] 
);

    // Permanent masks for each vector mode (64-bit masks)
    // Zeros are placed at the MSB of each non-final element to block Booth boundary crossing
    localparam [WIDTH-1:0] MASK_8BIT  = 64'h7F7F7F7F7F7F7F7F;  // Zeros at bits 7,15,23,31,39,47,55,63
    localparam [WIDTH-1:0] MASK_16BIT = 64'h7FFF7FFF7FFF7FFF;  // Zeros at bits 15,31,47,63
    localparam [WIDTH-1:0] MASK_32BIT = 64'h7FFFFFFF7FFFFFFF;  // Zeros at bits 31,63
    localparam [WIDTH-1:0] MASK_64BIT = 64'h7FFFFFFFFFFFFFFF;  // Zero at bit 63 (element MSB — enables unsigned correction in last_ppg)

    // Select mask based on vector mode (binary encoded: 0=8b,1=16b,2=32b,3=64b)
    wire [WIDTH-1:0] selected_mask;
    assign selected_mask = (vector_mode == 2'd0) ? MASK_8BIT  :  // 8-bit mode
                          (vector_mode == 2'd1) ? MASK_16BIT :  // 16-bit mode
                          (vector_mode == 2'd2) ? MASK_32BIT :  // 32-bit mode
                          (vector_mode == 2'd3) ? MASK_64BIT :  // 64-bit mode
                          MASK_64BIT; 

    
    wire [NUM_PP-2:0] selze;
    wire [NUM_PP-2:0] selp1;
    wire [NUM_PP-2:0] selp2;
    wire [NUM_PP-2:0] seln1;
    wire [NUM_PP-2:0] seln2;
    wire [7:0] boundary_bits;
 
    
    booth_recoder #(.WIDTH(WIDTH)) booth_rec(
        .multiplier(multiplier),
        .mask(selected_mask),
        .is_unsigned(is_unsigned),
        .selze(selze),
        .selp1(selp1),
        .selp2(selp2),
        .seln1(seln1),
        .seln2(seln2),
        .boundary_bits(boundary_bits)
    );

    genvar i;
    generate
        for(i=0;i<NUM_PP-1;i=i+1) begin
            ppg #(.WIDTH(WIDTH)) pp (
                .multiplicand(multiplicand),
                .vector_mode(vector_mode),
                .index(i),
                .is_unsigned(is_unsigned),
                .hot_ones((i == 0) ? '0 : {seln2[i-1],seln1[i-1]}),
                .selze(selze[i]),
                .selp1(selp1[i]),
                .selp2(selp2[i]),
                .seln1(seln1[i]),
                .seln2(seln2[i]),
                .partial_product(PPs[i])
            );
        end
    endgenerate

    last_ppg #(.WIDTH(WIDTH)) last_pp (
        .multiplicand(multiplicand),
        .vector_mode(vector_mode),
        .boundry_bits(boundary_bits),
        .seln1(seln1),
        .seln2(seln2),
        .partial_product(PPs[NUM_PP-1])
    );
    
endmodule