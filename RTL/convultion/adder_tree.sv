module adder_tree #(
	parameter integer N_INPUTS  = 9,
	parameter integer DATA_WIDTH = 16
) (
	input  signed [DATA_WIDTH-1 : 0] inputs [0:N_INPUTS-1],
	output signed [DATA_WIDTH-1 : 0] sum
);

	localparam integer STAGES = (N_INPUTS > 1) ? $clog2(N_INPUTS) : 1;

	wire signed [DATA_WIDTH-1:0] stage_wires [0:STAGES][0:((1<<STAGES)-1)];

	genvar s, k;

	for (k = 0; k < N_INPUTS; k = k + 1) begin : init_stage
		assign stage_wires[0][k] = inputs[k];
	end

	// Nested generate: pairwise addition across stages
	for (s = 0; s < STAGES; s = s + 1) begin : reduce_stage
		// number of elements present at this stage (ceiling division)
		localparam integer ELEMENTS = (N_INPUTS + (1 << s) - 1) >> s;
		for (k = 0; k < ELEMENTS; k = k + 1) begin : pairwise
			if ((2 * k + 1) < ELEMENTS) begin
				assign stage_wires[s+1][k] = stage_wires[s][2*k] + stage_wires[s][2*k+1];
			end else begin
				assign stage_wires[s+1][k] = stage_wires[s][2*k];
			end
		end
	end

	// final sum at top of tree
	assign sum = stage_wires[STAGES][0];

endmodule

