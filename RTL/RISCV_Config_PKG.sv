`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/09/2025 11:44:02 AM
// Design Name: 
// Module Name: RISCV_Config_PKG
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

package RISCV_PKG;

    parameter 
    REG_WIDTH = 64,                     // Register width in bits
    REG_COUNT = 32,                     // Number of registers in the register file
    ADDRESS_PORT_W = $clog2(REG_COUNT), // Address width to index registers
    // INSTRUCTION_SIZE = 32,              // Instruction width in bits
    // IMMEDIATE_SIZE = 32,
    // WORD_LENGTH = 32,
    // OPCODE_SIZE = 7,
    // MEM_WIDTH=4, 
    // MEM_SIZE = 268435456, 
    // HALF_MEM = 32768,
    // MEM_ROWS = 1 << 25;
    MLEN = 512,                         // Memory Interface width in bits
    VLEN = 1024,                        // Vector Register width in bits
    ELEN = 64,                          // Maximum element width in bits
    BYTE = 8,                           // Constant for More Readable Code
    NUM_LAYERS = $clog2(MLEN/BYTE),     // Number of layers needed for the control logic in the DROM
    OFFSET_W = $clog2(REG_WIDTH/BYTE),  // Byte offset width bits
    MLENB = MLEN/BYTE,                  // Memory Interface width in bytes
    VLENB = VLEN/BYTE,                  // Vector Register width in bytes
    ELENB = ELEN/BYTE                   // Maximum element width in bytes
    ; 
endpackage
