// MAC.v - Multiply-Accumulate for conv layer using Q12.20 fixed-point
// All values are signed Q12.20 (TOTAL_WIDTH = 32, FRAC = 20)
module convolution #(
    parameter KERNEL_SIZE = 3,
    // Q-format: INT_WIDTH integer bits, FRAC fractional bits
    parameter INT_WIDTH = 12,
    parameter FRAC_WIDTH = 20
) (
    input  wire clk,
    input  wire rst,
    input  signed [(INT_WIDTH+FRAC_WIDTH)-1:0] din [0:KERNEL_SIZE*KERNEL_SIZE-1],
    input  signed [(INT_WIDTH+FRAC_WIDTH)-1:0] weights [0:KERNEL_SIZE*KERNEL_SIZE-1],
    output signed [(INT_WIDTH+FRAC_WIDTH)-1:0] dout
);

    localparam TOTAL_WIDTH = INT_WIDTH+FRAC_WIDTH;
    wire signed [2*TOTAL_WIDTH-1:0] products [0:KERNEL_SIZE*KERNEL_SIZE-1];
    
    // Generate multiplication for each element
    genvar i;
    generate
        for (i = 0; i < KERNEL_SIZE*KERNEL_SIZE; i = i + 1) begin : mul_loop
                booth_wallace_mul_frac #(
                    .INT_WIDTH(INT_WIDTH),
                    .FRAC_WIDTH(FRAC_WIDTH)
                ) mul_inst (
                    .a(din[i]),
                    .b(weights[i]),
                    .clk(clk),
                    .rst(rst),
                    .result(products[i])
                );
        end
    endgenerate

    // Adder tree to sum all products
    wire signed [2*TOTAL_WIDTH-1:0] sum_result;
    adder_tree #(
        .N_INPUTS(KERNEL_SIZE*KERNEL_SIZE),
        .DATA_WIDTH(2*TOTAL_WIDTH)
    ) adder_tree_inst (
        .inputs(products),
        .sum(sum_result)
    );

    assign dout = sum_result[FRAC_WIDTH +: TOTAL_WIDTH]; // Take the middle bits for Q-format

endmodule