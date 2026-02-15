
module N_full_adder #(
    parameter n = 8
) (
    input  wire [n-1:0] a,
    input  wire [n-1:0] b,
    input  wire cin,
    output wire [n-1:0] sum,
    output wire cout
);
    wire [n:0] carry;
    assign carry[0] = cin;

    genvar i;
    generate
        for (i = 0; i < n; i = i + 1) begin : full_adder_bits
            Full_Adder fa_inst (
                .a(a[i]),
                .b(b[i]),
                .cin(carry[i]),
                .sum(sum[i]),
                .cout(carry[i+1])
            );
        end
    endgenerate

    assign cout = carry[n];    
endmodule