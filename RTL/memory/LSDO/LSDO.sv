import RISCV_PKG::*;

module LSDO (
    // input clk,
    input mode,     // 1 for load, 0 for store, Used for DROM and LSDO
    input data_dir, // 0 for forward, 1 for backward
    input [BYTE-1:0] shift, // Shift amount for byte shifter
    input [MLENB-1:0][BYTE-1:0] data_in,
    
    // Used for DROM configuration
    input [2:0] SEW,
    input [OFFSET_W-1:0] offset,
    input [2:0] stride,
    output [MLENB-1:0][BYTE-1:0] data_out,
    output [MLENB-1:0] valid_out
);

    wire [MLENB-1:0][BYTE-1:0] reverser_out;
    wire [MLENB-1:0][BYTE-1:0] drom_out;
    wire [MLENB-1:0][BYTE-1:0] shifter_out;
    wire [MLENB-1:0] drom_valid_out;
    wire [MLENB-1:0] reverser_valid_out;
    wire [MLENB-1:0] shifter_valid_out;

    // reg  dir_reg;
    // reg  mode_reg;
    // reg  [BYTE-1:0] shift_reg;

    reverser reverser (
        .data_in(mode ? data_in : drom_out),
        .valid_in(drom_valid_out),
        .stride_dir(data_dir),
        .data_out(reverser_out),
        .valid_out(reverser_valid_out)
    );
    
    DROM drom_inst (
        .data_in(mode ? reverser_out : shifter_out),
        .stride(stride),
        .SEW(SEW),
        .offset(offset),
        .mode(mode),
        // .clk(clk),
        .data_out(drom_out),
        .valid_out(drom_valid_out)
    );

    // always @(posedge clk) begin
    //     mode_reg <= mode;
    //     dir_reg <= data_dir;
    //     shift_reg <= shift;
    // end

    byte_shifter byte_shifter_inst (
        .data_in(mode ? drom_out : data_in),
        .valid_in(drom_valid_out),
        .shift(shift),
        .shift_dir(mode), // For load (mode=1), shift right; for store (mode=0), shift left
        .data_out(shifter_out),
        .valid_out(shifter_valid_out)
    );

    assign data_out = mode ? shifter_out : reverser_out;
    assign valid_out = mode ? shifter_valid_out : reverser_valid_out;

endmodule