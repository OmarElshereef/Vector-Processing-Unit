module conv_part #(
    parameter KERNEL_SIZE = 3,
    parameter INT_WIDTH = 12,
    parameter FRAC_WIDTH = 20,
    // Make TOTAL_WIDTH a parameter so it can be used in port ranges
    parameter TOTAL_WIDTH = INT_WIDTH + FRAC_WIDTH
) (
    input  wire clk,
    input  wire rst,
    input  wire valid_in,
    input  signed [TOTAL_WIDTH-1:0] din [0:KERNEL_SIZE*KERNEL_SIZE-1],
    input  signed [TOTAL_WIDTH-1:0] weights [0:KERNEL_SIZE*KERNEL_SIZE-1],
    output signed [TOTAL_WIDTH-1:0] dout
);
    
    // Module implementation
    reg signed [TOTAL_WIDTH-1:0] kernel_weights [0:KERNEL_SIZE*KERNEL_SIZE-1];
    wire signed [TOTAL_WIDTH-1:0] conv_dout;
    integer i,j;
    reg valid_out;

    always @(negedge clk or negedge rst) begin
        if (!rst) begin
            // Initialize weights to zero on reset
            for (i = 0; i < KERNEL_SIZE*KERNEL_SIZE; i = i + 1) begin
                // use indexed part-select for variable index: start +: width
                kernel_weights[i] <= {TOTAL_WIDTH{1'b0}};
            end
            valid_out <= 1'b0;
        end else if (valid_in) begin
            // Load new weights when valid_in is high
            for (j = 0; j < KERNEL_SIZE*KERNEL_SIZE; j = j + 1) begin
                kernel_weights[j] <= weights[j];
                valid_out <= 1'b1;
            end
        end
    end

    // Instantiate convolution module
    convolution #(
        .KERNEL_SIZE(KERNEL_SIZE),
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) conv_inst (
        .clk(clk),
        .rst(rst),
        .din(din),
        .weights(kernel_weights),
        .dout(conv_dout)
    );

    assign dout = valid_out ? conv_dout : 0;

endmodule