module regFileBank #(parameter WIDTH = 64, parameter REG_COUNT = 32, parameter ADDR_WIDTH = $clog2(REG_COUNT))
	(
	input clk,
	input rst,
	input [ADDR_WIDTH-1:0] read_addr,
	input read_en,
	output reg [WIDTH-1:0] read_data,
	input [ADDR_WIDTH-1:0] write_addr,
	input write_en,
	input [WIDTH-1:0] write_data);

	reg [WIDTH-1:0] mem [0:REG_COUNT-1];

	always @(posedge clk) begin
		if (write_en)
			mem[write_addr] <= write_data;
		if (read_en)
			read_data <= mem[read_addr];
	end
endmodule
	