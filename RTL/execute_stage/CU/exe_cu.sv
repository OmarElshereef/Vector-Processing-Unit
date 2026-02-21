module executeControlUnit #(
    parameter ADDR_WIDTH = 5
)(
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  instr_valid,
    input  wire [ADDR_WIDTH-1:0] rs1,
    input  wire [ADDR_WIDTH-1:0] rs2,
    output reg  [ADDR_WIDTH-1:0] read_addr,
    output reg                   read_en,
    output reg                   latch_en
);
    // Only state we need to remember across cycles
    reg                  fetch_b;
    reg [ADDR_WIDTH-1:0] rs2_saved;

    // Combinational output logic ? responds to inputs immediately,
    // no clock cycle wasted before BRAM sees the address
    always @(*) begin
        if (rst) begin
            read_addr = 0;
            read_en   = 0;
            latch_en  = 0;
        end else if (fetch_b) begin
            read_addr = rs2_saved;
            read_en   = 1;
            latch_en  = 0;
        end else if (instr_valid) begin
            read_addr = rs1;
            read_en   = 1;
            latch_en  = 1;
        end else begin
            read_addr = 0;
            read_en   = 0;
            latch_en  = 0;
        end
    end

    // Sequential state ? just the fetch_b flag and rs2 capture
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fetch_b   <= 0;
            rs2_saved <= 0;
        end else begin
            if (instr_valid && !fetch_b) begin
                fetch_b   <= 1;
                rs2_saved <= rs2;
            end else begin
                fetch_b <= 0;
            end
        end
    end

endmodule