// ============================================================
// Wallace Tree Summation
// Compresses NUM_INPUTS vectors of WIDTH bits into 1 sum.
//
// Uses classical 3:2 compressors (full adders) in each bit position.
// ============================================================

module wallace_tree #(
    parameter WIDTH = 32,
    parameter NUM_INPUTS = 8
)(
    // Flattened inputs: NUM_INPUTS vectors of WIDTH bits packed into one bus.
    // Use generate-time slicing to extract each WIDTH-bit input.
    input  wire [WIDTH-1:0] inputs [0:NUM_INPUTS-1],
    output wire [WIDTH-1:0] sum
);

    // Maximum levels (safe upper bound)
    localparam MAX_LEVEL = $clog2(NUM_INPUTS) * 2; 

    // Level wires (full tree allocated)
    wire [WIDTH-1:0] level [0:MAX_LEVEL][0:NUM_INPUTS-1];

    // Constant function to compute node count at a given reduction level.
    // This simulates the iterative 3:2 reduction performed at elaboration time
    // so generate/for conditions remain constant expressions.
    function integer count_at_level;
        input integer lvl;
        integer t;
        integer g;
        integer ii;
    begin
        t = NUM_INPUTS;
        for (ii = 0; ii < lvl; ii = ii + 1) begin
            g = t / 3;
            t = g*2 + (t % 3);
        end
        count_at_level = t;
    end
    endfunction

    genvar k;
    generate
        for (k=0; k<NUM_INPUTS; k=k+1) begin
            assign level[0][k] = inputs[k];
        end
    endgenerate


    // ------------------------------
    // WALLACE REDUCTION LEVELS
    // ------------------------------
    genvar L;
    generate
        for (L = 0; L < MAX_LEVEL; L = L + 1) begin : REDUCE_LEVEL

            // Compute counts at this level (constant at elaboration time)
            localparam integer COUNT = count_at_level(L);
            localparam integer GROUPS = COUNT / 3;
            localparam integer LEFTOVER = COUNT % 3;

            // 3:2 compress groups
            for (k = 0; k < GROUPS; k = k + 1) begin : COMPRESS
                wire [WIDTH-1:0] s;
                wire [WIDTH-1:0] c;

                no_ripple_n_full_adder #(.WIDTH(WIDTH)) fa (
                    .a(level[L][k*3]),
                    .b(level[L][k*3+1]),
                    .c(level[L][k*3+2]),
                    .sum(s),
                    .cout(c)
                );

                assign level[L+1][k*2]   = s;
                assign level[L+1][k*2+1] = {c[WIDTH-2:0], 1'b0};
            end

            // Pass leftover uncompressed inputs
            for (k = 0; k < LEFTOVER; k = k + 1) begin : PASS
                assign level[L+1][GROUPS*2 + k] = level[L][GROUPS*3 + k];
            end

        end
    endgenerate


    // ------------------------------
    // FINAL ADDITION
    // ------------------------------
    wire [WIDTH-1:0] A = level[MAX_LEVEL][0];
    wire [WIDTH-1:0] B = (count_at_level(MAX_LEVEL) > 1)
                            ? level[MAX_LEVEL][1]
                            : {WIDTH{1'b0}};

    assign sum = A + B;

endmodule
