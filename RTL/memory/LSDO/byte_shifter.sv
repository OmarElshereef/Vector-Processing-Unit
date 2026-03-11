import RISCV_PKG::*;

module byte_shifter (
    input [MLENB-1:0][BYTE-1:0] data_in,
    input [MLENB-1:0] valid_in,
    input [BYTE-1:0] shift,
    input shift_dir, // 0 for right shift, 1 for left shift
    output [MLENB-1:0][BYTE-1:0] data_out,
    output [MLENB-1:0] valid_out
);
    genvar i;
    generate
        for (i = 0; i < MLENB; i = i + 1) begin : shift_loop
            assign data_out[i] = shift_dir ? 
                                 ((i >= shift) ? data_in[i - shift] : 8'b0):          // Left shift
                                 ((i + shift < MLENB) ? data_in[i + shift] : 8'b0);   // Right shift
            assign valid_out[i] = shift_dir ? 
                                 ((i >= shift) ? valid_in[i - shift] : 1'b0) :        // Left shift
                                 ((i + shift < MLENB) ? valid_in[i + shift] : 1'b0); // Right shift
        end
    endgenerate
endmodule