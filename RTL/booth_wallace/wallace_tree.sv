module wallace_tree #(
    parameter WIDTH = 32,
    parameter NUM_INPUTS = 33
    // NUM_INPUTS should be a power of 4 plus 1 (e.g., 5, 17, 65) to fit the reduction pattern
)(
    input  wire [WIDTH-1:0] inputs [0:NUM_INPUTS-1],
    input  wire is_unsigned,
    output wire [WIDTH-1:0] sum
);

    localparam MAX_LEVEL = $clog2(NUM_INPUTS) / 2;

    wire [WIDTH-1:0] level [0:MAX_LEVEL][0:NUM_INPUTS-2];
    wire [WIDTH-1:0] final_sum, final_carry;
    wire [WIDTH-1:0] extra_input = is_unsigned ? inputs[NUM_INPUTS-1] : {WIDTH{1'b0}};

    genvar k;
    generate
        for (k = 0; k < NUM_INPUTS-1; k = k + 1) begin
            assign level[0][k] = inputs[k];
        end
    endgenerate

    genvar L;
    generate
        for (L = 0; L < MAX_LEVEL; L = L + 1) begin : REDUCE_LEVEL
            for (k = 0; k < (NUM_INPUTS >> (L+2)); k = k + 1) begin : COMPRESS
                wire [WIDTH-1:0] s, c;
                CSA_4_2 #(.WIDTH(WIDTH)) csa (
                    .a(level[L][k*4]),
                    .b(level[L][k*4+1]),
                    .c(level[L][k*4+2]),
                    .d(level[L][k*4+3]),
                    .sum(s),
                    .cout(c)
                );
                assign level[L+1][k*2]   = s;
                assign level[L+1][k*2+1] = c;
            end
        end
    endgenerate

    CSA_3_2 #(.WIDTH(WIDTH)) csa_last (
        .a(level[MAX_LEVEL][0]),
        .b(level[MAX_LEVEL][1]),
        .c(extra_input),
        .sum(final_sum),
        .cout(final_carry)
    );

    assign sum = final_sum + final_carry;

endmodule