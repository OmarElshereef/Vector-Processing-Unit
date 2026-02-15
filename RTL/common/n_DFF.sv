module n_DFF #(parameter N = 8) (
    input wire [N-1:0] d,
    input wire clk,
    input wire rst,
    output reg [N-1:0] Q
);
    always@(posedge clk) begin
        if (rst)
            Q <= {N{1'b0}};
        else
            Q <= d;
    end
endmodule