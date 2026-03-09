module CSA_3_2 #(
    parameter WIDTH = 8
)
(
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire [WIDTH-1:0] c,
    input wire [WIDTH-1:0] carry_kill = {WIDTH{1'b1}},
    output wire [WIDTH-1:0] sum,
    output wire [WIDTH-1:0] cout
);
    wire [WIDTH-1:0] temp_cout;
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : bit_full_adder
            
            Full_Adder fa_inst (
                .a(a[i]),
                .b(b[i]),
                .cin(c[i]),  // Apply carry kill to the carry input
                .sum(sum[i]),
                .cout(temp_cout[i])
            );
        end
    endgenerate
    assign cout = ((temp_cout << 1) & carry_kill);
endmodule