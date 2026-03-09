module CSA_4_2 #(
    parameter WIDTH = 8
)
(
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire [WIDTH-1:0] c,
    input  wire [WIDTH-1:0] d,
    input  wire [WIDTH-1:0] carry_kill = {WIDTH{1'b1}},
    output wire [WIDTH-1:0] sum,
    output wire [WIDTH-1:0] cout
);

    wire [WIDTH-1:0] sum_1,carry_1;
    CSA_3_2 #(.WIDTH(WIDTH)) csa1 (
        .a(a),
        .b(b),
        .c(c),
        .carry_kill(carry_kill),
        .sum(sum_1),
        .cout(carry_1)
    );


    CSA_3_2 #(.WIDTH(WIDTH)) csa2 (
        .a(sum_1),
        .b(carry_1),
        .c(d),
        .carry_kill(carry_kill),
        .sum(sum),
        .cout(cout)
    );
    
endmodule