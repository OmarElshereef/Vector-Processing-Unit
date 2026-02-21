module regMemory #(
    parameter WIDTH      = 512,
    parameter ELEN_WIDTH = 64,
    parameter REG_COUNT  = 32,
    parameter ADDR_WIDTH = $clog2(REG_COUNT)
)(
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  read_en,
    input  wire                  write_en,
    input  wire [ADDR_WIDTH-1:0] read_addr,
    input  wire [ADDR_WIDTH-1:0] write_addr,
    input  wire [WIDTH-1:0]      write_data,
    output wire [WIDTH-1:0]      out
);

    localparam BANK_COUNT = WIDTH / ELEN_WIDTH;

    genvar i;
    generate
        for (i = 0; i < BANK_COUNT; i = i + 1) begin : gen_banks
            regFileBank #(
                .WIDTH      (ELEN_WIDTH),
                .REG_COUNT  (REG_COUNT),
                .ADDR_WIDTH (ADDR_WIDTH)
            ) bank_inst (
                .clk        (clk),
                .rst        (rst),
                .read_en    (read_en),
                .read_addr  (read_addr),
                .read_data  (out[i*ELEN_WIDTH +: ELEN_WIDTH]),
                .write_en   (write_en),
                .write_addr (write_addr),
                .write_data (write_data[i*ELEN_WIDTH +: ELEN_WIDTH])
            );
        end
    endgenerate

endmodule