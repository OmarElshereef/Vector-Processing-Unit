module instruction_buffer #(
    parameters
    INSTR_WIDTH     = 32,
    SCALAR_VAL_SIZE = 32,
    VTYPE_WIDTH     = 8,
    VL_WIDTH        = 32
) (
    ports
    input logic start_vloop,
    input logic[5:0] current_dispatch_opcode,
    input logic [SCALAR_VAL_SIZE-1:0] scalar_value_in,
    input logic [VTYPE_WIDTH-1:0] vtype_in,
    input logic vm_in,

    output logic 
);
    
endmodule