
module Full_Adder (
    input wire a,
    input wire b,
    input wire cin,
    output wire sum,
    output wire cout
);

    wire sum_ab, carry_ab, carry_abc;

    Half_Adder ha1 (
        .a(a),
        .b(b),
        .sum(sum_ab),
        .carry(carry_ab)
    );
    
    Half_Adder ha2 (
        .a(sum_ab),
        .b(cin),
        .sum(sum),
        .carry(carry_abc)
    );

    // Final carry out
    assign cout = carry_ab | carry_abc;
endmodule