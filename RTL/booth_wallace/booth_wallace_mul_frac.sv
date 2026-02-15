module booth_wallace_mul_frac #(
    parameter INT_WIDTH = 8,
    parameter FRAC_WIDTH = 8
)(
    input  [INT_WIDTH+FRAC_WIDTH-1:0] a,
    input  [INT_WIDTH+FRAC_WIDTH-1:0] b,
    input  clk,
    input rst,
    output [2*(INT_WIDTH+FRAC_WIDTH)-1:0] result
);

    reg [INT_WIDTH+FRAC_WIDTH-1:0] a_reg;
    reg [INT_WIDTH+FRAC_WIDTH-1:0] b_reg;
    reg [2*(INT_WIDTH+FRAC_WIDTH)-1:0] result_reg;
    wire [2*(INT_WIDTH+FRAC_WIDTH)-1:0] result_tmp;

    always @(negedge clk or negedge rst) begin
        if (!rst) begin
            a_reg <= 0;
            b_reg <= 0;
            result_reg <= 0;
        end else begin
            a_reg <= a;
            b_reg <= b;
            result_reg <= result_tmp;
        end
    end

    booth_wallace_multiplier #(
        .WIDTH(INT_WIDTH+FRAC_WIDTH)
    ) multiplier_inst (
        .multiplicand(a_reg),
        .multiplier(b_reg),
        .product(result_tmp)
    );
    assign result = result_reg;
endmodule