module last_ppg #(
    parameter WIDTH = 64
)(
    input  [WIDTH-1:0]   multiplicand,
    input  [1:0]         vector_mode,   // 0:8b  1:16b  2:32b  3:64b
    input  [7:0]         boundry_bits,
    input  [31:0] seln1,
    input  [31:0] seln2,
    output [2*WIDTH-1:0] partial_product
);

    reg  [2*WIDTH-1:0] pp;
    assign partial_product = pp;

    integer k;

    always_comb begin
        pp = '0;
        case (vector_mode)
            2'b00: begin // 8-bit mode
                for (k = 0; k < 8; k = k + 1) begin
                    pp[k*16+8 +: 8] = boundry_bits[k] ? multiplicand[k*8 +: 8] : '0;
                    pp[k*16+7] = seln2[4*(k+1)-1];
                    pp[k*16+6] = seln1[4*(k+1)-1];
                end
            end
            2'b01: begin // 16-bit mode
                for (k = 0; k < 4; k = k + 1) begin
                    pp[k*32+16 +: 16] = boundry_bits[k*2+1] ? multiplicand[k*16 +: 16] : '0;
                    pp[k*32+15] = seln2[8*(k+1)-1];
                    pp[k*32+14] = seln1[8*(k+1)-1];
                end
            end
            2'b10: begin // 32-bit mode
                for (k = 0; k < 2; k = k + 1) begin
                    pp[k*64+32 +: 32] = boundry_bits[k*4+3] ? multiplicand[k*32 +: 32] : '0;
                    pp[k*64+31] = seln2[16*(k+1)-1];
                    pp[k*64+30] = seln1[16*(k+1)-1];
                end
            end
            2'b11: begin // 64-bit mode
                pp[WIDTH +: WIDTH] = boundry_bits[7] ? multiplicand : '0;
                pp[63] = seln2[31];
                pp[62] = seln1[31];
            end
            default: pp = '0;
        endcase
    end

endmodule