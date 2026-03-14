module regFileBank #(
    parameter ELEN       = 64,
    parameter REG_COUNT  = 32,
    parameter ADDR_WIDTH = $clog2(REG_COUNT)
)(
    input wire clk,
    input wire rst,

    input  wire [ADDR_WIDTH-1:0] read_addr_a,
    input  wire                  read_en_a,
    output reg  [ELEN-1:0]       read_data_a,
    
    output reg  [ELEN-1:0]       read_data_b,

    input  wire [ADDR_WIDTH-1:0] write_addr,
    input  wire                  write_en,
    input  wire [ELEN-1:0]       write_data
);

    reg [ELEN-1:0] mem [0:REG_COUNT-1];

    always @(posedge clk) begin
        if (write_en) begin
            mem[write_addr] <= write_data;
        end
        
        if (read_en_a) begin
            read_data_a <= mem[read_addr_a];
        end
        
        read_data_b <= mem[0];
    end

endmodule