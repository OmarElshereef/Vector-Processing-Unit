module executeLane #(
	parameter LANE_WIDTH = 64,
	UNIT_WIDTH = 16,
	SEW_BITS = $clog2($clog2(LANE_WIDTH/UNIT_WIDTH) + 1), 
	FINAL_BITS = (SEW_BITS < 1) ? 1 : SEW_BITS
)(
	input clk,
	input is_signed,
	input latch_en,
	input chained_carry,
	input [FINAL_BITS: 0] eew_log2,
	input [LANE_WIDTH-1:0] operand,
	input [2:0] opcode,
	output [LANE_WIDTH-1:0] result,
	output[2*LANE_WIDTH-1:0] result_wide,
	output carry_out
);

	reg [LANE_WIDTH-1:0] op_latch;

	laneALU #(.LANE_WIDTH(LANE_WIDTH), .UNIT_WIDTH(UNIT_WIDTH), .SEW_BITS(SEW_BITS), .FINAL_BITS(FINAL_BITS))
		ALU (.operand1(op_latch), .operand2(operand), .eew_log2(eew_log2), .carry_in(chained_carry), .opcode(opcode), .result(result), .result_wide(result_wide), .carry_out(carry_out), .is_signed(is_signed));

	always @(posedge clk) begin
		if(latch_en)
			op_latch <= operand;
	end
endmodule
			