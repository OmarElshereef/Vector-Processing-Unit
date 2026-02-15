module reduction_tree #(
	parameter integer N_INPUTS  = 9,
	parameter integer DATA_WIDTH = 16
) (
	input  signed [DATA_WIDTH-1 : 0] inputs [0:N_INPUTS-1],
	input [1:0] op,
	output signed [DATA_WIDTH-1 : 0] result
);

	localparam integer STAGES = (N_INPUTS > 1) ? $clog2(N_INPUTS) : 1;

	wire signed [DATA_WIDTH-1:0] stage_wires [0:STAGES][0:((1<<STAGES)-1)];

	genvar s, k;

	for (k = 0; k < N_INPUTS; k = k + 1) begin : init_stage
		assign stage_wires[0][k] = inputs[k];
	end

	// 00: addition
	// 01: subtraction
	// 10: maximum
	// 11: minimum

	// Nested generate: pairwise operations across stages  
	for (s = 0; s < STAGES; s = s + 1) begin : reduce_stage
		// number of elements present at this stage (ceiling division)
		localparam integer ELEMENTS = (N_INPUTS + (1 << s) - 1) >> s;
		for (k = 0; k < ELEMENTS; k = k + 1) begin : pairwise
			if ((2 * k + 1) < ELEMENTS) begin
				case (op)
					2'b00: assign stage_wires[s+1][k] = stage_wires[s][2*k] + stage_wires[s][2*k+1];
					2'b01: assign stage_wires[s+1][k] = stage_wires[s][2*k] - stage_wires[s][2*k+1];
					2'b10: assign stage_wires[s+1][k] = (stage_wires[s][2*k] > stage_wires[s][2*k+1]) ? stage_wires[s][2*k] : stage_wires[s][2*k+1];
					2'b11: assign stage_wires[s+1][k] = (stage_wires[s][2*k] < stage_wires[s][2*k+1]) ? stage_wires[s][2*k] : stage_wires[s][2*k+1];
					default: assign stage_wires[s+1][k] = stage_wires[s][2*k] + stage_wires[s][2*k+1];
				endcase
			end else begin
				assign stage_wires[s+1][k] = stage_wires[s][2*k];
			end
		end
	end

	// // approach 2
	// for (s = 0; s < STAGES; s = s + 1) begin : reduce_stage
	// 	// number of elements present at this stage (ceiling division)
	// 	localparam integer ELEMENTS = (N_INPUTS + (1 << s) - 1) >> s;
	// 	for (k = 0; k < ELEMENTS; k = k + 1) begin : pairwise
	// 		if ((2 * k + 1) < ELEMENTS) begin
	// 			wire signed [DATA_WIDTH-1:0] operand_a, operand_b;
    //         	wire signed [DATA_WIDTH-1:0] sum;
	// 			assign operand_a = stage_wires[s][2*k];
	// 			assign operand_b = (op[0] || op[1]) ? -stage_wires[s][2*k+1] : stage_wires[s][2*k+1];
	// 			assign sum = operand_a + operand_b;
	// 			assign stage_wires[s+1][k] = op[1] ? 
	// 			(op[0] == sum[DATA_WIDTH-1] ? stage_wires[s][2*k] : stage_wires[s][2*k+1])
	// 			: sum;
	// 		end else begin
	// 			assign stage_wires[s+1][k] = stage_wires[s][2*k];
	// 		end
	// 	end
	// end

	// final top of tree
	assign result = stage_wires[STAGES][0];

endmodule

