
// Used to fix metastability issues by using a two-stage flip-flop synchronizer
module sync_n_DFF #(parameter N = 8) (
    input wire [N-1:0] d,
    input wire clk,
    input wire rst,
    output wire [N-1:0] Q
);

    wire [N-1:0] Q1;

    n_DFF #(N) dff1 (
        .d(d),
        .clk(clk),
        .rst(rst),
        .Q(Q1)
    );

    n_DFF #(N) dff2 (
        .d(Q1),
        .clk(clk),
        .rst(rst),
        .Q(Q)
    );
endmodule