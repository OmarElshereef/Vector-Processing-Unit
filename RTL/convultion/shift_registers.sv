module shift_registers #(
    parameter DATA_WIDTH = 8,
    parameter ROW_LENGTH = 32,
    parameter KERNEL_SIZE = 3,
    parameter LINE_LENGTH = (KERNEL_SIZE-1)*ROW_LENGTH + KERNEL_SIZE
) (
    input wire clk,
    input wire rst,
    input wire valid_in,
    input wire [DATA_WIDTH-1:0] din,
    output wire valid_out_start,
    output wire valid_out_end,
    // Replace unpacked array port with packed wide vector compatible with Verilog-2001
    output wire signed [DATA_WIDTH-1:0] dout [0:KERNEL_SIZE*KERNEL_SIZE-1]
);
    reg [DATA_WIDTH:0] shift_regs [0:LINE_LENGTH-1];

    integer i;
    // Shift register for line buffering (shift-register implementation)
    always @(negedge clk or negedge rst) begin
        if (!rst) begin
            for (i = 0; i < LINE_LENGTH; i = i + 1) begin
                shift_regs[i] <= 0;
            end
        end else begin
            shift_regs[0] <= {valid_in, din}; // Store valid bit with data
            for (i = 1; i < LINE_LENGTH; i = i + 1) begin
                shift_regs[i] <= shift_regs[i-1];
            end
        end
    end

    // Output logic
    assign valid_out_end = shift_regs[LINE_LENGTH-1][DATA_WIDTH];
    assign valid_out_start = shift_regs[0][DATA_WIDTH];
    
    genvar r, c;
    generate
        for (r = 0; r < KERNEL_SIZE; r = r + 1) begin : row_loop
            for (c = 0; c < KERNEL_SIZE; c = c + 1) begin : col_loop
                assign dout[KERNEL_SIZE*KERNEL_SIZE - 1 - (r*KERNEL_SIZE+c)] = shift_regs[r*ROW_LENGTH + c][DATA_WIDTH-1:0];
            end
        end
    endgenerate
    

endmodule
