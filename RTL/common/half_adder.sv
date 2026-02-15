module Half_Adder (
    input wire a,
    input wire b,
    output wire sum,
    output wire carry
);

    assign sum = a ^ b;      // Sum is the XOR of a and b
    assign carry = a & b;    // Carry is the AND of a and b
endmodule