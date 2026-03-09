module vtype_decoder #(
    parameter ELEN = 64
) (
    input  logic [2:0] vsew,
    input  logic [2:0] vlmul,
    input  logic       vta, // vector tail agnostic
    input  logic       vma, // vector mask agnostic

    output logic [6:0]  eew,// effective element width in bits
    output logic [3:0]  reg_group_size,
    output logic        lmul_fractional,
    output logic        vta_out,
    output logic        vma_out,
    output logic        vtype_illegal
);

    logic [6:0] eew_internal;
    logic       vsew_illegal;
    logic       vlmul_illegal;
    logic       elen_violation;

    always_comb begin
        vsew_illegal = 1'b0;
        unique case (vsew)
            3'b000:  eew_internal = 7'd8;
            3'b001:  eew_internal = 7'd16;
            3'b010:  eew_internal = 7'd32;
            3'b011:  eew_internal = 7'd64;
            default: begin
                eew_internal = 7'd8;
                vsew_illegal = 1'b1;
            end
        endcase
    end

    always_comb begin
        vlmul_illegal   = 1'b0;
        lmul_fractional = 1'b0;

        unique case (vlmul)
            3'b000: begin // 1
                reg_group_size = 4'd1;
            end
            3'b001: begin // 2
                reg_group_size = 4'd2;
            end
            3'b010: begin // 4
                reg_group_size = 4'd4;
            end
            3'b011: begin // 8
                reg_group_size = 4'd8;
            end

            3'b111: begin // 1/2
                reg_group_size  = 4'd1;
                lmul_fractional = 1'b1;
            end
            3'b110: begin // 1/4
                reg_group_size  = 4'd1;
                lmul_fractional = 1'b1;
            end
            3'b101: begin // 1/8
                reg_group_size  = 4'd1;
                lmul_fractional = 1'b1;
            end

            3'b100: begin
                reg_group_size = 4'd1;
                vlmul_illegal  = 1'b1;
            end
        endcase
    end


    assign elen_violation = (eew_internal > ELEN[6:0]);

    assign eew          = eew_internal;
    assign vta_out      = vta;
    assign vma_out      = vma;
    assign vtype_illegal = vsew_illegal | vlmul_illegal | elen_violation;

endmodule