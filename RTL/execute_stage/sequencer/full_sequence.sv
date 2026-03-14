// =============================================================================
//  vector_unit_core.sv
//
//  Simple wrapper connecting micro_sequencer → executeStage
//  Exposes decode inputs and register file write port.
//  For testing/verification of sequencer-execute communication.
// =============================================================================
module vector_unit_core #(
    parameter integer VLEN       = 512,
    parameter integer ELEN       = 64,
    parameter integer REG_COUNT  = 32,
    parameter integer UNIT_WIDTH = 16,
    parameter integer MAX_LMUL   = 8,
    parameter integer EXEC_CYCLES = 2,

    // Derived
    parameter integer LANE_COUNT = VLEN / ELEN,
    parameter integer ADDR_WIDTH = $clog2(REG_COUNT),
    parameter integer SEW_BITS   = $clog2($clog2(VLEN/UNIT_WIDTH) + 1),
    parameter integer FINAL_BITS = (SEW_BITS < 1) ? 1 : SEW_BITS,
    parameter integer VL_WIDTH   = $clog2(VLEN) + 1
) (
    input  logic clk,
    input  logic rst_n,

    // =========================================================================
    // Decode Interface (from instruction decoder)
    // =========================================================================
    input  logic                  dec_valid,
    input  logic [ADDR_WIDTH-1:0] dec_vs1,
    input  logic [ADDR_WIDTH-1:0] dec_vs2,
    input  logic [ADDR_WIDTH-1:0] dec_vd,
    input  logic [VL_WIDTH-1:0]   dec_vl,
    input  logic [2:0]            dec_vsew,
    input  logic [2:0]            dec_vlmul,
    input  logic                  dec_vta,
    input  logic                  dec_vma,
    input  logic [2:0]            dec_opcode,
    input  logic                  dec_is_signed,
    input  logic                  dec_mask_en,

    output logic                  seq_busy,

    // =========================================================================
    // Register File Write Port (for writeback)
    // =========================================================================
    input  logic                  reg_write_en,
    input  logic [ADDR_WIDTH-1:0] reg_write_addr,
    input  logic [VLEN-1:0]       reg_write_data,
    
    // =========================================================================
    // Execute Stage Result Output
    // =========================================================================
    output logic [VLEN-1:0]       exec_result,
    output logic [2*VLEN-1:0]     exec_result_wide
);

    // =========================================================================
    // Internal Signals: Sequencer → Execute
    // =========================================================================
    logic                  seq_exec_valid;
    logic [ADDR_WIDTH-1:0] seq_exec_vs1_addr;
    logic [ADDR_WIDTH-1:0] seq_exec_vs2_addr;
    logic [ADDR_WIDTH-1:0] seq_exec_vd_addr;
    logic [2:0]            seq_exec_opcode;
    logic [FINAL_BITS:0]   seq_exec_eew_log2;
    logic                  seq_exec_is_signed;
    logic [LANE_COUNT-1:0] seq_exec_lane_mask;
    logic                  seq_exec_last_chunk;
    logic seq_exec_mask_en;
    
    // =========================================================================
    // Microsequencer Instance
    // =========================================================================
    micro_sequencer #(
        .VLEN        (VLEN),
        .ELEN        (ELEN),
        .REG_COUNT   (REG_COUNT),
        .UNIT_WIDTH  (UNIT_WIDTH),
        .MAX_LMUL    (MAX_LMUL),
        .EXEC_CYCLES (EXEC_CYCLES)
    ) u_sequencer (
        .clk              (clk),
        .rst_n            (rst_n),
        
        // Decode inputs
        .dec_valid        (dec_valid),
        .dec_vs1          (dec_vs1),
        .dec_vs2          (dec_vs2),
        .dec_vd           (dec_vd),
        .dec_vl           (dec_vl),
        .dec_vsew         (dec_vsew),
        .dec_vlmul        (dec_vlmul),
        .dec_vta          (dec_vta),
        .dec_vma          (dec_vma),
        .dec_opcode       (dec_opcode),
        .dec_is_signed    (dec_is_signed),
        .dec_mask_en      (dec_mask_en),
        
        // Status
        .seq_busy         (seq_busy),
        
        // Outputs to execute stage
        .exec_instr_valid (seq_exec_valid),
        .exec_vs1_addr    (seq_exec_vs1_addr),
        .exec_vs2_addr    (seq_exec_vs2_addr),
        .exec_vd_addr     (seq_exec_vd_addr),
        .exec_opcode      (seq_exec_opcode),
        .exec_eew_log2    (seq_exec_eew_log2),
        .exec_is_signed   (seq_exec_is_signed),
        .lane_mask        (seq_exec_lane_mask),
        .last_chunk       (seq_exec_last_chunk)
    );

    // =========================================================================
    // Execute Stage Instance
    // =========================================================================
    executeStage #(
        .VLEN       (VLEN),
        .ELEN       (ELEN),
        .REG_COUNT  (REG_COUNT),
        .ADDR_WIDTH (ADDR_WIDTH),
        .UNIT_WIDTH (UNIT_WIDTH),
        .SEW_BITS   (SEW_BITS),
        .FINAL_BITS (FINAL_BITS)
    ) u_execute (
        .clk         (clk),
        .rst         (~rst_n),  // executeStage uses active-high reset
        
        // From sequencer
        .instr_valid (seq_exec_valid),
        .vs1_addr    (seq_exec_vs1_addr),
        .vs2_addr    (seq_exec_vs2_addr),
        .vd_addr     (seq_exec_vd_addr),
        .eew_log2    (seq_exec_eew_log2),
        .opcode      (seq_exec_opcode),
        .is_signed   (seq_exec_is_signed),
        
        // Register file write port
        .write_en    (reg_write_en),
        .write_addr  (reg_write_addr),
        .write_data  (reg_write_data),
         
        .lane_mask   (seq_exec_lane_mask),
        .mask_en     (seq_exec_mask_en),
        // Results
        .result      (exec_result),
        .result_wide (exec_result_wide)
    );

    // =========================================================================
    // Lane mask and last_chunk are currently unused by executeStage
    // In a full implementation, these would control writeback logic
    // =========================================================================
    // Unused: seq_exec_lane_mask
    // Unused: seq_exec_last_chunk

endmodule