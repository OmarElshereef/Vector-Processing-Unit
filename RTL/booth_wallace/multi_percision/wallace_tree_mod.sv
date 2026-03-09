module wallace_tree_mod #(
    parameter WIDTH      = 128,
    parameter NUM_INPUTS = 33
)(
    input  wire [WIDTH-1:0] inputs [0:NUM_INPUTS-1],
    input  wire [1:0] vector_mode,  // 0:8b  1:16b  2:32b  3:64b (used for carry-kill in the first layer)
    output wire [WIDTH-1:0] sum
);

    localparam MAX_LEVEL = $clog2(NUM_INPUTS-1) - 1;

    // Carry kill mask: zeros the bits at element boundaries to prevent
    // carry propagation across SIMD lane boundaries.
    //   vector_mode 0 (8-bit)  -> kill at bits 8, 16, 24, 32, ...
    //   vector_mode 1 (16-bit) -> kill at bits 16, 32, 48, ...
    //   vector_mode 2 (32-bit) -> kill at bits 32, 64, ...
    //   vector_mode 3 (64-bit) -> no kill
    localparam MASK_8BIT  = 128'hFFFE_FFFE_FFFE_FFFE_FFFE_FFFE_FFFE_FFFF;  // Zeros at bits 16,32,48,64,80,96,112
    localparam MASK_16BIT = 128'hFFFF_FFFE_FFFF_FFFE_FFFF_FFFE_FFFF_FFFF;  // Zeros at bits 32,64,96
    localparam MASK_32BIT = 128'hFFFF_FFFF_FFFF_FFFE_FFFF_FFFF_FFFF_FFFF;  // Zero at bit 64
    localparam MASK_64BIT = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;  // No zeros
    wire [WIDTH-1:0] carry_kill_mask = (vector_mode == 2'b00) ? MASK_8BIT[WIDTH-1:0]  :
                                      (vector_mode == 2'b01) ? MASK_16BIT[WIDTH-1:0] :
                                      (vector_mode == 2'b10) ? MASK_32BIT[WIDTH-1:0] :
                                      MASK_64BIT[WIDTH-1:0];

    wire [WIDTH-1:0] level [0:MAX_LEVEL][0:NUM_INPUTS-2];
    wire [WIDTH-1:0] final_sum, final_carry;
    wire [WIDTH-1:0] extra_input = inputs[NUM_INPUTS-1];

    genvar k;
    generate
        for (k = 0; k < NUM_INPUTS-1; k = k + 1) begin
            assign level[0][k] = inputs[k];
        end
    endgenerate

    genvar L;
    generate
        for (L = 0; L < MAX_LEVEL; L = L + 1) begin : REDUCE_LEVEL
            for (k = 0; k < (NUM_INPUTS >> (L+2)); k = k + 1) begin : COMPRESS
                wire [WIDTH-1:0] s, c;
                CSA_4_2 #(.WIDTH(WIDTH)) csa (
                    .a(level[L][k*4]),
                    .b(level[L][k*4+1]),
                    .c(level[L][k*4+2]),
                    .d(level[L][k*4+3]),
                    .carry_kill(carry_kill_mask),
                    .sum(s),
                    .cout(c)
                );
                assign level[L+1][k*2]   = s;
                assign level[L+1][k*2+1] = c;
            end
        end
    endgenerate

    CSA_3_2 #(.WIDTH(WIDTH)) csa_last (
        .a(level[MAX_LEVEL][0]),
        .b(level[MAX_LEVEL][1]),
        .c(extra_input),
        .carry_kill(carry_kill_mask),
        .sum(final_sum),
        .cout(final_carry)
    );

    // Lane-wise final addition to prevent carry propagation across SIMD boundaries
    wire [WIDTH-1:0] sum_8bit, sum_16bit, sum_32bit, sum_64bit;
    
    genvar i;
    generate
        // 8-bit mode: 8 lanes
        for (i = 0; i < 8; i = i + 1) begin : LANE_8
            assign sum_8bit[i*16 +: 16] = final_sum[i*16 +: 16] + final_carry[i*16 +: 16];
        end
        
        // 16-bit mode: 4 lanes
        for (i = 0; i < 4; i = i + 1) begin : LANE_16
            assign sum_16bit[i*32 +: 32] = final_sum[i*32 +: 32] + final_carry[i*32 +: 32];
        end
        
        // 32-bit mode: 2 lanes
        for (i = 0; i < 2; i = i + 1) begin : LANE_32
            assign sum_32bit[i*64 +: 64] = final_sum[i*64 +: 64] + final_carry[i*64 +: 64];
        end
        
        // 64-bit mode: 1 lanes
        assign sum_64bit = final_sum + final_carry;
    endgenerate

    // Select the appropriate lane-wise sum based on vector_mode
    assign sum = (vector_mode == 2'b00) ? sum_8bit  :
                 (vector_mode == 2'b01) ? sum_16bit :
                 (vector_mode == 2'b10) ? sum_32bit :
                                          sum_64bit;

endmodule