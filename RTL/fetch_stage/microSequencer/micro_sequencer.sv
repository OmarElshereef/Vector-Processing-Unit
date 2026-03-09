module micro_sequencer #(
    parameters
    no_lanes = 4,
) (
    ports
    input logic clk,
    input logic rst_n,
    
    input logic [1:0] inst_type, 
    input logic [1:0] op_type,   
    input logic mask_bit,        
    input logic [6:0] operation,
    
    
    
    input logic is_valid_instr,  

);
    
endmodule