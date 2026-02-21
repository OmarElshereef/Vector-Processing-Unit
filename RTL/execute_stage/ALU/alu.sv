module addModule #(
    parameter LENGTH = 32, 
    SUB_LENGTH = 8, 
    ELEN_WIDTH = $clog2($clog2(LENGTH/SUB_LENGTH) + 1), 
    FINAL_WIDTH = (ELEN_WIDTH < 1) ? 1 : ELEN_WIDTH
) (
    input [2:0] mode, //0 addition, 1 subtraction, 2 OR, 3 AND, 4 NOT, 5 XOR, 6 MUL
    input [FINAL_WIDTH:0] elen,
    input [LENGTH-1:0] op1,
    input [LENGTH-1:0] op2,
    input carry_in,
    output reg [LENGTH-1:0] out,
    output reg carry
);
    //-------- submodule generation ---------//
    localparam INSTANCES_COUNT = LENGTH/SUB_LENGTH;
    wire carry_bus [INSTANCES_COUNT:0];
    wire [LENGTH-1: 0] operational_out;
    wire [LENGTH-1: 0] op2_modified;
    
    //------- operation mode handling ----------//
    assign op2_modified = op2 ^ {LENGTH{mode[0]}};
    assign carry_bus[0] = (mode == 3'd1 || mode == 3'd0) ? carry_in : 1'b0;
    
    //------- instances loop ----------//
    genvar i;
    generate 
        for (i = 0; i < INSTANCES_COUNT; i = i + 1)
        begin: gen_adders
            wire effective_cin;
            if (i == 0) begin
                assign effective_cin = carry_bus[0];
            end else begin
                wire is_boundary;
                assign is_boundary = (i % (1 << elen) == 0); 
                assign effective_cin = is_boundary ? (mode == 3'd1) : carry_bus[i];
            end
            
            // Logical operations - use continuous assignment
            wire [SUB_LENGTH-1:0] unit_op1 = op1[i*SUB_LENGTH +: SUB_LENGTH];
            wire [SUB_LENGTH-1:0] unit_op2 = (mode == 3'd1) ? op2_modified[i*SUB_LENGTH +: SUB_LENGTH] : op2[i*SUB_LENGTH +: SUB_LENGTH];
	    wire [SUB_LENGTH:0] arith_result;
            wire [SUB_LENGTH-1:0] unit_result;
            
	    assign arith_result = unit_op1 + unit_op2 + effective_cin;

	    assign carry_bus[i+1] = (mode == 3'd0 || mode == 3'd1) ? 
                         arith_result[SUB_LENGTH] : 1'b0;
	    
            assign unit_result =(mode == 3'd0 || mode == 3'd1) ? arith_result[SUB_LENGTH-1:0] :
				(mode == 3'd2) ? (unit_op1 | unit_op2) :
                                (mode == 3'd3) ? (unit_op1 & unit_op2) :
                                (mode == 3'd4) ? (~unit_op1) :
                                (mode == 3'd5) ? (unit_op1 ^ unit_op2) :
				(mode == 3'd6) ? (unit_op1 * unit_op2) :
				{SUB_LENGTH{1'bx}};
            
            assign operational_out[i*SUB_LENGTH +: SUB_LENGTH] = unit_result;
        end
    endgenerate
    
    assign out = operational_out;
    assign carry = carry_bus[INSTANCES_COUNT] ^ (mode == 3'd1);
endmodule