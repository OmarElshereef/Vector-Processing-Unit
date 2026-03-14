// =============================================================================
//  micro_sequencer.sv
//
//  Sits between the instruction decoder and executeStage.
//  Handles two things:
//
//  1. LMUL > 1 register group iteration
//     For LMUL=N the instruction operands span N consecutive registers.
//     The sequencer fires one instr_valid pulse per register, incrementing
//     vs1/vs2/vd addresses by 1 every 2 cycles (to match executeStage's
//     2-cycle operand fetch).
//
//  2. Tail lane mask
//     On each instr_valid pulse the sequencer computes a LANE_COUNT-wide
//     lane_mask where lane_mask[i]=1 means lane i holds at least one real
//     element (not a tail element beyond vl).
//
//  Timing (LMUL=2):
//    Cycle 0: dec_valid seen  → latch fields, step=0, cycle_count=0, S_RUNNING
//    Cycle 1: instr_valid=1, step=0, cycle_count=0, vs1+0/vs2+0/vd+0
//    Cycle 2: instr_valid=1, step=0, cycle_count=1, vs1+0/vs2+0/vd+0 (hold)
//    Cycle 3: instr_valid=1, step=1, cycle_count=0, vs1+1/vs2+1/vd+1
//    Cycle 4: instr_valid=1, step=1, cycle_count=1, vs1+1/vs2+1/vd+1, last_chunk=1
//    Cycle 5: S_IDLE, seq_busy=0
//
//  Parameters mirror executeStage exactly.
//  Depends on: vtype_decoder.sv
// =============================================================================
module micro_sequencer #(
    parameter integer VLEN       = 512,
    parameter integer ELEN       = 64,
    parameter integer REG_COUNT  = 32,
    parameter integer UNIT_WIDTH = 16,

    // Derived
    parameter integer LANE_COUNT = VLEN / ELEN,
    parameter integer ADDR_WIDTH = $clog2(REG_COUNT),
    parameter integer SEW_BITS   = $clog2($clog2(VLEN/UNIT_WIDTH) + 1),
    parameter integer FINAL_BITS = (SEW_BITS < 1) ? 1 : SEW_BITS,
    parameter integer VL_WIDTH   = $clog2(VLEN) + 1
) (
    input  logic clk,
    input  logic rst_n,

    // Decoded instruction from upstream
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

    // Stall to upstream
    output logic                  seq_busy,

    // Outputs to executeStage
    output logic                  exec_instr_valid,
    output logic [ADDR_WIDTH-1:0] exec_vs1_addr,
    output logic [ADDR_WIDTH-1:0] exec_vs2_addr,
    output logic [ADDR_WIDTH-1:0] exec_vd_addr,
    output logic [2:0]            exec_opcode,
    output logic [FINAL_BITS:0]   exec_eew_log2,
    output logic                  exec_is_signed,
    output logic                  exec_mask_en,
    output logic [LANE_COUNT-1:0] lane_mask,
    output logic                  last_chunk
);

    // =====================================================================
    // FSM state encoding
    // =====================================================================
    typedef enum logic [1:0] {
        S_IDLE    = 2'b00,
        S_RUNNING = 2'b01
    } state_t;

    state_t state, state_next;

    // =====================================================================
    // Latched instruction fields
    // =====================================================================
    logic [ADDR_WIDTH-1:0] lat_vs1, lat_vs2, lat_vd;
    logic [VL_WIDTH-1:0]   lat_vl;
    logic [2:0]            lat_vsew, lat_vlmul;
    logic                  lat_vta, lat_vma;
    logic [2:0]            lat_opcode;
    logic                  lat_is_signed;
    logic                  lat_mask_en;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lat_vs1       <= '0;  lat_vs2   <= '0;  lat_vd    <= '0;
            lat_vl        <= '0;
            lat_vsew      <= '0;  lat_vlmul <= '0;
            lat_vta       <= '0;  lat_vma   <= '0;
            lat_opcode    <= '0;
            lat_is_signed <= '0;
            lat_mask_en   <= '0;
        end else if (state == S_IDLE && dec_valid) begin
            lat_vs1       <= dec_vs1;
            lat_vs2       <= dec_vs2;
            lat_vd        <= dec_vd;
            lat_vl        <= dec_vl;
            lat_vsew      <= dec_vsew;
            lat_vlmul     <= dec_vlmul;
            lat_vta       <= dec_vta;
            lat_vma       <= dec_vma;
            lat_opcode    <= dec_opcode;
            lat_is_signed <= dec_is_signed;
            lat_mask_en   <= dec_mask_en;
        end
    end

    // =====================================================================
    // vtype_decoder instance
    // =====================================================================
    logic [6:0] vtd_eew;
    logic [3:0] vtd_reg_group_size;
    logic       vtd_lmul_frac;
    logic       vtd_vta_out, vtd_vma_out, vtd_illegal;

    logic [2:0] mux_vsew, mux_vlmul;
    
    assign mux_vsew  = (state == S_IDLE) ? dec_vsew  : lat_vsew;
    assign mux_vlmul = (state == S_IDLE) ? dec_vlmul : lat_vlmul;
    
    vtype_decoder #(.ELEN(ELEN)) u_vtype (
        .vsew            (mux_vsew),
        .vlmul           (mux_vlmul),
        .vta             (lat_vta),
        .vma             (lat_vma),
        .eew             (vtd_eew),
        .reg_group_size  (vtd_reg_group_size),
        .lmul_fractional (vtd_lmul_frac),
        .vta_out         (vtd_vta_out),
        .vma_out         (vtd_vma_out),
        .vtype_illegal   (vtd_illegal)
    );

    // =====================================================================
    // eew → eew_log2
    // =====================================================================
    logic [FINAL_BITS:0] eew_log2;

    always_comb begin
        unique case (vtd_eew)
            7'd8:    eew_log2 = (FINAL_BITS+1)'(0);
            7'd16:   eew_log2 = (FINAL_BITS+1)'(1);
            7'd32:   eew_log2 = (FINAL_BITS+1)'(2);
            7'd64:   eew_log2 = (FINAL_BITS+1)'(3);
            default: eew_log2 = (FINAL_BITS+1)'(0);
        endcase
    end

    // =====================================================================
    // Step counter - position within register group (0..reg_group_size-1)
    // Cycle counter - 2-cycle hold per step (0..1)
    // =====================================================================
    logic [3:0] step, step_next;
    logic       cycle_count, cycle_count_next;  // NEW: 0 or 1

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step        <= '0;
            cycle_count <= '0;
        end else begin
            step        <= step_next;
            cycle_count <= cycle_count_next;
        end
    end

    // =====================================================================
    // Tail lane mask
    // =====================================================================
    logic [VL_WIDTH-1:0] epr;   // elements per register
    logic [VL_WIDTH-1:0] epl;   // elements per lane

    always_comb begin
        unique case (vtd_eew)
            7'd8:  begin epr = VL_WIDTH'(VLEN/8);  epl = VL_WIDTH'(ELEN/8);  end
            7'd16: begin epr = VL_WIDTH'(VLEN/16); epl = VL_WIDTH'(ELEN/16); end
            7'd32: begin epr = VL_WIDTH'(VLEN/32); epl = VL_WIDTH'(ELEN/32); end
            7'd64: begin epr = VL_WIDTH'(VLEN/64); epl = VL_WIDTH'(ELEN/64); end
            default: begin epr = VL_WIDTH'(VLEN/64); epl = VL_WIDTH'(ELEN/64); end
        endcase
    end

    always_comb begin
        for (int i = 0; i < LANE_COUNT; i++) begin
            automatic logic [VL_WIDTH-1:0] first_elem;
            first_elem   = (VL_WIDTH'(step) * epr) + (VL_WIDTH'(i) * epl);
            lane_mask[i] = (first_elem < lat_vl) ? 1'b1 : 1'b0;
        end
    end

    // =====================================================================
    // FSM sequential
    // =====================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S_IDLE;
        else        state <= state_next;
    end

    // =====================================================================
    // FSM combinational
    // =====================================================================
    always_comb begin
        state_next       = state;
        step_next        = step;
        cycle_count_next = cycle_count;
        exec_instr_valid = 1'b0;
        last_chunk       = 1'b0;
        seq_busy         = 1'b0;

        unique case (state)
            S_IDLE: begin
                step_next        = 4'd0;
                cycle_count_next = 1'b0;
                if (dec_valid)
                    state_next = S_RUNNING;
            end

            S_RUNNING: begin
                seq_busy         = 1'b1;
                exec_instr_valid = 1'b1;

                // Check if this is the last step
                if (step == 4'(vtd_reg_group_size - 4'd1)) begin
                    // On the last step, check if we've completed 2 cycles
                    if (cycle_count == 1'b1) begin
                        // Completed 2 cycles on last step → done
                        last_chunk       = 1'b1;
                        step_next        = 4'd0;
                        cycle_count_next = 1'b0;
                        state_next       = S_IDLE;
                    end else begin
                        // First cycle of last step → hold for one more cycle
                        cycle_count_next = 1'b1;
                        state_next       = S_RUNNING;
                    end
                end else begin
                    // Not the last step yet
                    if (cycle_count == 1'b1) begin
                        // Completed 2 cycles → move to next step
                        step_next        = step + 4'd1;
                        cycle_count_next = 1'b0;
                        state_next       = S_RUNNING;
                    end else begin
                        // First cycle → hold for one more cycle
                        cycle_count_next = 1'b1;
                        state_next       = S_RUNNING;
                    end
                end
            end
            
            default: state_next = S_IDLE;
        endcase
    end

    // =====================================================================
    // Drive executeStage outputs
    // =====================================================================
    assign exec_vs1_addr  = ADDR_WIDTH'(lat_vs1 + ADDR_WIDTH'(step));
    assign exec_vs2_addr  = ADDR_WIDTH'(lat_vs2 + ADDR_WIDTH'(step));
    assign exec_vd_addr   = ADDR_WIDTH'(lat_vd  + ADDR_WIDTH'(step));
    assign exec_opcode    = lat_opcode;
    assign exec_eew_log2  = eew_log2;
    assign exec_is_signed = lat_is_signed;
    assign exec_mask_en = lat_mask_en;
    
endmodule