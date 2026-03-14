// =============================================================================
//  vtype_decoder.sv
//  Decodes vtype CSR fields into control signals.
//  Purely combinational.
// =============================================================================
module vtype_decoder #(
    parameter integer ELEN = 64
) (
    input  logic [2:0] vsew,
    input  logic [2:0] vlmul,
    input  logic       vta,
    input  logic       vma,

    output logic [6:0] eew,              // element width in bits: 8/16/32/64
    output logic [3:0] reg_group_size,   // registers per operand: 1/2/4/8
    output logic       lmul_fractional,  // 1 = LMUL < 1
    output logic       vta_out,
    output logic       vma_out,
    output logic       vtype_illegal
);

    logic [6:0] eew_internal;
    logic       vsew_illegal, vlmul_illegal, elen_violation;

    always_comb begin
        vsew_illegal = 1'b0;
        unique case (vsew)
            3'b000:  eew_internal = 7'd8;
            3'b001:  eew_internal = 7'd16;
            3'b010:  eew_internal = 7'd32;
            3'b011:  eew_internal = 7'd64;
            default: begin eew_internal = 7'd8; vsew_illegal = 1'b1; end
        endcase
    end

    always_comb begin
        vlmul_illegal   = 1'b0;
        lmul_fractional = 1'b0;
        unique case (vlmul)
            3'b000: reg_group_size = 4'd1;
            3'b001: reg_group_size = 4'd2;
            3'b010: reg_group_size = 4'd4;
            3'b011: reg_group_size = 4'd8;
            3'b111: begin reg_group_size = 4'd1; lmul_fractional = 1'b1; end
            3'b110: begin reg_group_size = 4'd1; lmul_fractional = 1'b1; end
            3'b101: begin reg_group_size = 4'd1; lmul_fractional = 1'b1; end
            3'b100: begin reg_group_size = 4'd1; vlmul_illegal   = 1'b1; end
        endcase
    end

    assign elen_violation = (eew_internal > ELEN[6:0]);
    assign eew            = eew_internal;
    assign vta_out        = vta;
    assign vma_out        = vma;
    assign vtype_illegal  = vsew_illegal | vlmul_illegal | elen_violation;

endmodule