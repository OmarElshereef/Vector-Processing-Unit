module no_ripple_N_full_adder #(
    parameter WIDTH = 8
)
(
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire [WIDTH-1:0] c,
    output wire [WIDTH-1:0] sum,
    output wire [WIDTH-1:0] cout
);
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : bit_full_adder
            Full_Adder fa_inst (
                .a(a[i]),
                .b(b[i]),
                .cin(c[i]),
                .sum(sum[i]),
                .cout(cout[i])
            );
        end
    endgenerate
endmodule