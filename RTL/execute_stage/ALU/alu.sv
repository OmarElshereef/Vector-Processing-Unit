module laneALU #(
    parameter LANE_WIDTH = 64,
    parameter UNIT_WIDTH = 16,
    parameter SEW_BITS   = $clog2($clog2(LANE_WIDTH/UNIT_WIDTH) + 1),
    parameter FINAL_BITS = (SEW_BITS < 1) ? 1 : SEW_BITS
) (
    // Operation selector
    input [2:0] opcode,  // 0=ADD, 1=SUB, 2=OR, 3=AND, 4=NOT, 5=XOR, 6=MUL
    
    // Element width selector (log2 encoded: 0=8b, 1=16b, 2=32b, 3=64b)
    input [FINAL_BITS:0] eew_log2,
    
    // Sign control for multiplication
    input is_signed,     // 1=signed multiply, 0=unsigned multiply
    
    // Operands (full lane width)
    input [LANE_WIDTH-1:0] operand1,
    input [LANE_WIDTH-1:0] operand2,
    
    // Carry chain
    input  carry_in,
    output carry_out,
    
    output [LANE_WIDTH-1:0]   result,
    output [2*LANE_WIDTH-1:0] result_wide  // For widening multiply operations
);

    localparam UNIT_COUNT = LANE_WIDTH / UNIT_WIDTH;
    
    // =========================================================================
    // Internal Signals
    // =========================================================================
    wire [UNIT_COUNT:0] carry_chain;
    wire [LANE_WIDTH-1:0] operand2_inverted;
    wire [LANE_WIDTH-1:0] arith_logic_result;
    wire [2*LANE_WIDTH-1:0] mul_result_wide;
    wire [1:0] mul_vector_mode = eew_log2[1:0];

    // =========================================================================
    // Multiplier Instantiation
    // =========================================================================
    booth_wallace_mul_mod #(
        .WIDTH(LANE_WIDTH)
    ) multiplier (
        .multiplier    (operand1),
        .multiplicand  (operand2),
        .vector_mode   (mul_vector_mode),    // Map eew_log2 to vector_mode
        .is_unsigned   (~is_signed),       // Invert: multiplier uses is_unsigned
        .result        (mul_result_wide)
    );
    
    // =========================================================================
    // Operation Mode Handling
    // =========================================================================
    assign operand2_inverted = operand2 ^ {LANE_WIDTH{opcode[0]}};
    assign carry_chain[0] = (opcode == 3'd1 || opcode == 3'd0) ? carry_in : 1'b0;
    
    // =========================================================================
    // Arithmetic/Logic Unit Array
    // =========================================================================
    genvar i;
    generate 
        for (i = 0; i < UNIT_COUNT; i = i + 1) begin: gen_alu_units
            
            // Carry propagation logic
            wire unit_carry_in;
            if (i == 0) begin
                assign unit_carry_in = carry_chain[0];
            end else begin
                wire is_element_boundary;
                assign is_element_boundary = (i % (1 << eew_log2) == 0);
                assign unit_carry_in = is_element_boundary ? 
                                       (opcode == 3'd1) : 
                                       carry_chain[i];
            end
            
            // Extract unit operands
            wire [UNIT_WIDTH-1:0] unit_op1;
            wire [UNIT_WIDTH-1:0] unit_op2;
            wire [UNIT_WIDTH-1:0] unit_result;
            
            assign unit_op1 = operand1[i*UNIT_WIDTH +: UNIT_WIDTH];
            assign unit_op2 = (opcode == 3'd1) ? 
                              operand2_inverted[i*UNIT_WIDTH +: UNIT_WIDTH] :
                              operand2[i*UNIT_WIDTH +: UNIT_WIDTH];
            
            // Arithmetic operation
            wire [UNIT_WIDTH:0] arith_sum;
            assign arith_sum = unit_op1 + unit_op2 + unit_carry_in;
            assign carry_chain[i+1] = (opcode == 3'd0 || opcode == 3'd1) ? 
                                      arith_sum[UNIT_WIDTH] : 1'b0;
            
            // Operation selection (excluding MUL - handled separately)
            assign unit_result = (opcode == 3'd0 || opcode == 3'd1) ? arith_sum[UNIT_WIDTH-1:0] :
                                 (opcode == 3'd2) ? (unit_op1 | unit_op2) :
                                 (opcode == 3'd3) ? (unit_op1 & unit_op2) :
                                 (opcode == 3'd4) ? (~unit_op1) :
                                 (opcode == 3'd5) ? (unit_op1 ^ unit_op2) :
                                 {UNIT_WIDTH{1'bx}};
            
            assign arith_logic_result[i*UNIT_WIDTH +: UNIT_WIDTH] = unit_result;
        end
    endgenerate
    
    // =========================================================================
    // Output Selection
    // =========================================================================
    assign carry_out = carry_chain[UNIT_COUNT] ^ (opcode == 3'd1);
    
    // Select between arithmetic/logic result and multiply result
    assign result = (opcode == 3'd6) ? mul_result_wide[LANE_WIDTH-1:0] : arith_logic_result;
    
    // Provide full wide result for widening multiply operations
    assign result_wide = mul_result_wide;

endmodule