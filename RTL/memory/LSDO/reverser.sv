import RISCV_PKG::*;

module reverser (
    input [MLENB-1:0][BYTE-1:0] data_in,
    input [MLENB-1:0] valid_in,
    input stride_dir, // 0 for forward, 1 for backward
    output [MLENB-1:0][BYTE-1:0] data_out,
    output [MLENB-1:0] valid_out
);

    generate
        for (genvar i = 0; i < MLENB; i = i + 1) begin : data_buffering
            assign data_out[i] = stride_dir ? data_in[MLENB - 1 - i] : data_in[i];
            assign valid_out[i] = stride_dir ? valid_in[MLENB - 1 - i] : valid_in[i];
        end
    endgenerate
endmodule