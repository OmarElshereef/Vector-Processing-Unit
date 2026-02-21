module executeLane #(
	parameter LENGTH = 64,
	SUB_LENGTH = 16,
	ELEN_WIDTH = $clog2($clog2(LENGTH/SUB_LENGTH) + 1), 
	FINAL_WIDTH = (ELEN_WIDTH < 1) ? 1 : ELEN_WIDTH
)(
	input clk,
	input latch_en,
	input chained_carry,
	input [FINAL_WIDTH: 0] elen,
	input [LENGTH-1:0] operand,
	input [2:0] opcode,
	output [LENGTH-1:0] result,
	output carry_out
);

	reg [LENGTH-1:0] op_latch;

	addModule #(.LENGTH(LENGTH), .SUB_LENGTH(SUB_LENGTH), .ELEN_WIDTH(ELEN_WIDTH), .FINAL_WIDTH(FINAL_WIDTH))
		ALU (.op1(op_latch), .op2(operand), .elen(elen), .carry_in(chained_carry), .mode(opcode), .out(result), .carry(carry_out));

	always @(posedge clk) begin
		if(latch_en)
			op_latch <= operand;
	end
endmodule
			