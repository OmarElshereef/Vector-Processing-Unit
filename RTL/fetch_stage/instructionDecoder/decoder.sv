module decoder (
    input logic [31:0] instr_in,
    
    output logic [1:0] inst_type, // 00 invalid, 01 memory load , 10 memory store, 11 vector arithmetic
    output logic [4:0] vd, rd,
    output logic vd_valid, vs1_valid, vs2_valid,
    output logic [4:0] src1,
    output logic [4:0] vs2,
    output logic [1:0] op_type, // 00 vectorvector, 01 vectorscalar, 10 vectorimmediate, 11 configuration
    output logic mask_bit, // For masked vector operations
    output logic [5:0] operation // real opcode 
);


assign inst_type = (instr_in[6:0] == 7'b0000111) ? 2'b01 : 
                (instr_in[6:0] == 7'b0100111) ? 2'b10 : 
                (instr_in[6:0] == 7'b1010111) ? 2'b11 : 
                2'b00;

assign op_type = (instr_in[14:12] == 3'b000 || instr_in[14:12]== 3'b001|| instr_in[14:12]== 3'b010) ? 2'b00 :
                (instr_in[14:12] == 3'b100 || instr_in[14:12]== 3'b110|| instr_in[14:12]== 3'b101) ? 2'b01 :
                (instr_in[14:12] == 3'b011) ? 2'b10 :
                (instr_in[14:12] == 3'b111) ? 2'b11 :
                2'b00; // default to vector-vector for invalid instructions

assign vd = rd = instr_in[11:7]; 
assign vd_valid = (op_type == 2'b11) ? 1'b0 : 1'b1; // vd is not valid for configuration instructions

assign src1 = instr_in[19:15];
assign vs1_valid = (op_type == 2'b00 ) ? 1'b1 : 1'b0;
assign vs2 = instr_in[24:20];
assign vs2_valid = (inst_type == 2'b11) ? 1'b1 : 1'b0;

assign mask_bit = instr_in[25];
assign operation = instr_in[31:26];
 
    
endmodule