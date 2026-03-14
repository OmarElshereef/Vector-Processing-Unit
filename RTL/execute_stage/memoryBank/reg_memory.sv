module regMemory #(
    parameter VLEN       = 512,
    parameter ELEN       = 64,
    parameter REG_COUNT  = 32,
    parameter ADDR_WIDTH = $clog2(REG_COUNT)
)(
    input  wire                     clk,
    input  wire                     rst,
    
    input  wire                     read_en,
    input  wire [ADDR_WIDTH-1:0]    read_addr,
    output wire [VLEN-1:0]          out,
    
    input  wire                     write_en,
    input  wire [ADDR_WIDTH-1:0]    write_addr,
    input  wire [VLEN-1:0]          write_data,
    
    input  wire [VLEN/ELEN-1:0]     lane_mask,
    input  wire                     mask_en,
    
    output wire [VLEN-1:0]          v0_mask
);

    localparam BANK_COUNT = VLEN / ELEN;
    wire [BANK_COUNT-1:0] lane_write_en;
    
    genvar i;
    generate
        for (i = 0; i < BANK_COUNT; i = i + 1) begin : gen_write_enables
            
            wire is_writing_v0;
            wire v0_element_mask;
            wire tail_mask_ok;
            wire element_mask_ok;
            
            assign is_writing_v0 = (write_addr == {ADDR_WIDTH{1'b0}});
            
            assign v0_element_mask = v0_mask[i * ELEN];
            
            assign tail_mask_ok = lane_mask[i];
            
            assign element_mask_ok = (!mask_en) || is_writing_v0 || v0_element_mask;
            
            assign lane_write_en[i] = write_en && tail_mask_ok && element_mask_ok;
            
        end
    endgenerate
    
    generate
        for (i = 0; i < BANK_COUNT; i = i + 1) begin : gen_banks
            
            regFileBank #(
                .ELEN       (ELEN),
                .REG_COUNT  (REG_COUNT),
                .ADDR_WIDTH (ADDR_WIDTH)
            ) bank_inst (
                .clk          (clk),
                .rst          (rst),
                
                .read_addr_a  (read_addr),
                .read_en_a    (read_en),
                .read_data_a  (out[i*ELEN +: ELEN]),

                .read_data_b  (v0_mask[i*ELEN +: ELEN]),
                
                .write_addr   (write_addr),
                .write_en     (lane_write_en[i]),
                .write_data   (write_data[i*ELEN +: ELEN])
            );
            
        end
    endgenerate

endmodule