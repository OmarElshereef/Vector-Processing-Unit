`timescale 1ns/1ps

module micro_sequencer_tb;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam VLEN       = 512;
    localparam ELEN       = 64;
    localparam REG_COUNT  = 32;
    localparam UNIT_WIDTH = 16;
    localparam LANE_COUNT = VLEN / ELEN;
    localparam ADDR_WIDTH = $clog2(REG_COUNT);
    localparam SEW_BITS   = $clog2($clog2(VLEN/UNIT_WIDTH) + 1);
    localparam FINAL_BITS = (SEW_BITS < 1) ? 1 : SEW_BITS;
    localparam VL_WIDTH   = $clog2(VLEN) + 1;

    // =========================================================================
    // Clock and reset
    // =========================================================================
    logic clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;

    // =========================================================================
    // DUT ports
    // =========================================================================
    logic                  dec_valid;
    logic [ADDR_WIDTH-1:0] dec_vs1, dec_vs2, dec_vd;
    logic [VL_WIDTH-1:0]   dec_vl;
    logic [2:0]            dec_vsew, dec_vlmul;
    logic                  dec_vta, dec_vma;
    logic [2:0]            dec_opcode;
    logic                  dec_is_signed, dec_mask_en;

    logic                  seq_busy;
    logic                  exec_instr_valid;
    logic [ADDR_WIDTH-1:0] exec_vs1_addr, exec_vs2_addr, exec_vd_addr;
    logic [2:0]            exec_opcode;
    logic [FINAL_BITS:0]   exec_eew_log2;
    logic                  exec_is_signed;
    logic [LANE_COUNT-1:0] lane_mask;
    logic                  last_chunk;

    // =========================================================================
    // DUT instantiation
    // =========================================================================
    micro_sequencer #(
        .VLEN       (VLEN),
        .ELEN       (ELEN),
        .REG_COUNT  (REG_COUNT),
        .UNIT_WIDTH (UNIT_WIDTH)
    ) dut (
        .clk              (clk),
        .rst_n            (rst_n),
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
        .seq_busy         (seq_busy),
        .exec_instr_valid (exec_instr_valid),
        .exec_vs1_addr    (exec_vs1_addr),
        .exec_vs2_addr    (exec_vs2_addr),
        .exec_vd_addr     (exec_vd_addr),
        .exec_opcode      (exec_opcode),
        .exec_eew_log2    (exec_eew_log2),
        .exec_is_signed   (exec_is_signed),
        .lane_mask        (lane_mask),
        .last_chunk       (last_chunk)
    );

    // =========================================================================
    // Statistics
    // =========================================================================
    integer total_tests  = 0;
    integer passed_tests = 0;
    integer failed_tests = 0;
    integer suite_pass, suite_fail;

    task suite_start;
        input string name;
    begin
        suite_pass = 0;
        suite_fail = 0;
        $display("\n--------------------------------------------------------------------------------");
        $display("%s", name);
        $display("--------------------------------------------------------------------------------");
    end
    endtask

    task suite_end;
    begin
        $display("  Suite: %0d passed, %0d failed", suite_pass, suite_fail);
    end
    endtask

    // =========================================================================
    // Captured outputs per instr_valid pulse (max LMUL=8 -> 8 pulses)
    // =========================================================================
    logic [ADDR_WIDTH-1:0] cap_vs1  [0:7];
    logic [ADDR_WIDTH-1:0] cap_vs2  [0:7];
    logic [ADDR_WIDTH-1:0] cap_vd   [0:7];
    logic [LANE_COUNT-1:0] cap_mask [0:7];
    logic                  cap_last [0:7];
    logic [FINAL_BITS:0]   cap_eew  [0:7];
    integer                cap_pulses;

    // =========================================================================
    // Task: drive one instruction, capture all instr_valid pulses
    //
    // Timing (from DUT FSM):
    //   posedge T0: dec_valid=1 seen  → state goes IDLE→RUNNING next cycle
    //   posedge T1: state=RUNNING     → exec_instr_valid=1, seq_busy=1  ← first pulse
    //   posedge T2: still RUNNING or DONE depending on reg_group_size
    //
    // Strategy: after pulsing dec_valid for one cycle, wait exactly ONE more
    // posedge (T1) and then start sampling exec_instr_valid on every posedge
    // until last_chunk is seen. No seq_busy polling - we use last_chunk as
    // the definitive exit condition since it is asserted on the same cycle
    // as the final exec_instr_valid pulse.
    // =========================================================================
task send_and_capture(
        input [ADDR_WIDTH-1:0] vs1, vs2, vd,
        input [VL_WIDTH-1:0]   vl,
        input [2:0]            vsew, vlmul,
        input [2:0]            opcode
    );
        integer i;
        integer timeout_counter;
    begin
        cap_pulses = 0;
        timeout_counter = 0;
        
        for (i = 0; i < 8; i = i + 1) begin
            cap_vs1[i] = 'x; cap_vs2[i] = 'x; cap_vd[i] = 'x;
            cap_mask[i] = 'x; cap_last[i] = 'x; cap_eew[i] = 'x;
        end

        // 1. Synchronize
        @(negedge clk);
        while (seq_busy) @(negedge clk);

        // 2. Drive
        dec_vs1 = vs1; dec_vs2 = vs2; dec_vd = vd; dec_vl = vl;
        dec_vsew = vsew; dec_vlmul = vlmul; dec_opcode = opcode;
        dec_valid = 1'b1;

        // 3. Handshake (T0)
        @(posedge clk);
        #1; // The DUT is now in S_RUNNING (State 1)
        dec_valid = 1'b0;

        // 4. Immediate Capture + Loop
        // We check right now because for LMUL=1, it's already running!
        while (1) begin
            // Is there a pulse active right now?
            if (exec_instr_valid) begin
                cap_vs1 [cap_pulses] = exec_vs1_addr;
                cap_vs2 [cap_pulses] = exec_vs2_addr;
                cap_vd  [cap_pulses] = exec_vd_addr;
                cap_mask[cap_pulses] = lane_mask;
                cap_last[cap_pulses] = last_chunk;
                cap_eew [cap_pulses] = exec_eew_log2;
                
                $display("DEBUG: Captured Pulse %0d | State: %0d | last=%b", 
                         cap_pulses, dut.state, last_chunk);
                
                cap_pulses = cap_pulses + 1;
                
                if (last_chunk) break; 
            end

            // Only wait for the NEXT clock if we haven't finished
            @(posedge clk);
            #1;
            
            timeout_counter = timeout_counter + 1;
            if (timeout_counter > 20) begin
                $display("ERROR: Timeout! State: %0d", dut.state);
                $finish;
            end
        end
    end
    endtask

    // =========================================================================
    // Check helpers
    // =========================================================================
    task check_pulse_count(
        input integer exp_count,
        input string  test_name
    );
    begin
        total_tests = total_tests + 1;
        if (cap_pulses === exp_count) begin
            passed_tests = passed_tests + 1;
            suite_pass   = suite_pass   + 1;
            $display("[PASS] %s", test_name);
        end else begin
            failed_tests = failed_tests + 1;
            suite_fail   = suite_fail   + 1;
            $display("[FAIL] %s", test_name);
            $display("  pulse count: got %0d  expected %0d", cap_pulses, exp_count);
        end
    end
    endtask

    task check_pulse(
        input integer          pulse_idx,
        input [ADDR_WIDTH-1:0] exp_vs1, exp_vs2, exp_vd,
        input [LANE_COUNT-1:0] exp_mask,
        input                  exp_last,
        input string           test_name
    );
        logic pass;
    begin
        pass = (cap_vs1 [pulse_idx] === exp_vs1)  &&
               (cap_vs2 [pulse_idx] === exp_vs2)  &&
               (cap_vd  [pulse_idx] === exp_vd)   &&
               (cap_mask[pulse_idx] === exp_mask) &&
               (cap_last[pulse_idx] === exp_last);

        total_tests = total_tests + 1;
        if (pass) begin
            passed_tests = passed_tests + 1;
            suite_pass   = suite_pass   + 1;
            $display("[PASS] %s", test_name);
        end else begin
            failed_tests = failed_tests + 1;
            suite_fail   = suite_fail   + 1;
            $display("[FAIL] %s", test_name);
            if (cap_vs1 [pulse_idx] !== exp_vs1)
                $display("  vs1_addr  : got %0d  expected %0d",   cap_vs1[pulse_idx],  exp_vs1);
            if (cap_vs2 [pulse_idx] !== exp_vs2)
                $display("  vs2_addr  : got %0d  expected %0d",   cap_vs2[pulse_idx],  exp_vs2);
            if (cap_vd  [pulse_idx] !== exp_vd)
                $display("  vd_addr   : got %0d  expected %0d",   cap_vd[pulse_idx],   exp_vd);
            if (cap_mask[pulse_idx] !== exp_mask)
                $display("  lane_mask : got %08b  expected %08b", cap_mask[pulse_idx], exp_mask);
            if (cap_last[pulse_idx] !== exp_last)
                $display("  last_chunk: got %0b  expected %0b",   cap_last[pulse_idx], exp_last);
        end
    end
    endtask

    // =========================================================================
    // Stimulus
    // =========================================================================
    initial begin
        $display("================================================================================");
        $display("  micro_sequencer Testbench");
        $display("  VLEN=%0d  ELEN=%0d  LANE_COUNT=%0d", VLEN, ELEN, LANE_COUNT);
        $display("================================================================================");

        rst_n      = 0;
        dec_valid  = 0;
        dec_vs1    = 0; dec_vs2   = 0; dec_vd    = 0;
        dec_vl     = 0; dec_vsew  = 0; dec_vlmul = 0;
        dec_vta    = 0; dec_vma   = 0;
        dec_opcode = 0; dec_is_signed = 0; dec_mask_en = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        // --------------------------------------------------------------------
        suite_start("SUITE 1: LMUL=1  eew=64  vl=8  (full register, no tail)");
        // eew=64 -> 1 elem/lane, vl=8 fills all 8 lanes exactly
        // expect: 1 pulse, mask=11111111, last=1
        // --------------------------------------------------------------------
        send_and_capture(5'd2, 5'd4, 5'd6, 10'd8,  3'b011, 3'b000, 3'd0);
        check_pulse_count(1, "1 instr_valid pulse");
        check_pulse(0, 5'd2, 5'd4, 5'd6, 8'b11111111, 1'b1,
                    "pulse 0: vs1=2 vs2=4 vd=6  mask=11111111  last=1");
        suite_end();

        // --------------------------------------------------------------------
        suite_start("SUITE 2: LMUL=1  eew=64  vl=5  (tail on lanes 5,6,7)");
        // vl=5 -> lanes 0-4 active, lanes 5-7 beyond vl
        // expect: 1 pulse, mask=00011111, last=1
        // --------------------------------------------------------------------
        send_and_capture(5'd2, 5'd4, 5'd6, 10'd5,  3'b011, 3'b000, 3'd0);
        check_pulse_count(1, "1 instr_valid pulse");
        check_pulse(0, 5'd2, 5'd4, 5'd6, 8'b00011111, 1'b1,
                    "pulse 0: mask=00011111  (lanes 5-7 tail)  last=1");
        suite_end();

        // --------------------------------------------------------------------
        suite_start("SUITE 3: LMUL=1  eew=32  vl=12  (tail on lanes 6,7)");
        // eew=32 -> 2 elems/lane, epr=16
        // lane 6: first_elem = 6*2 = 12, 12 < 12? NO -> tail
        // lane 7: first_elem = 7*2 = 14                -> tail
        // expect: 1 pulse, mask=00111111, last=1
        // --------------------------------------------------------------------
        send_and_capture(5'd2, 5'd4, 5'd6, 10'd12, 3'b010, 3'b000, 3'd0);
        check_pulse_count(1, "1 instr_valid pulse");
        check_pulse(0, 5'd2, 5'd4, 5'd6, 8'b00111111, 1'b1,
                    "pulse 0: mask=00111111  (lanes 6-7 tail)  last=1");
        suite_end();

        // --------------------------------------------------------------------
        suite_start("SUITE 4: LMUL=2  eew=64  vl=16  (two full registers)");
        // expect: 2 pulses, addresses bump by 1 each cycle
        //   pulse 0: vs1=2 vs2=4 vd=6  mask=11111111  last=0
        //   pulse 1: vs1=3 vs2=5 vd=7  mask=11111111  last=1
        // --------------------------------------------------------------------
        send_and_capture(5'd2, 5'd4, 5'd6, 10'd16, 3'b011, 3'b001, 3'd0);
        check_pulse_count(2, "2 instr_valid pulses");
        check_pulse(0, 5'd2, 5'd4, 5'd6, 8'b11111111, 1'b0,
                    "pulse 0: vs1=2 vs2=4 vd=6  mask=11111111  last=0");
        check_pulse(1, 5'd3, 5'd5, 5'd7, 8'b11111111, 1'b1,
                    "pulse 1: vs1=3 vs2=5 vd=7  mask=11111111  last=1");
        suite_end();

        // --------------------------------------------------------------------
        suite_start("SUITE 5: LMUL=4  eew=32  vl=40  (tail partway through)");
        // eew=32 -> epl=2, epr=16
        // step 0 elems  0-15: first_elem[0]=0          mask=11111111
        // step 1 elems 16-31: first_elem[0]=16         mask=11111111
        // step 2 elems 32-47: first_elem[4]=40 >= 40   mask=00001111
        // step 3 elems 48-63: first_elem[0]=48 >= 40   mask=00000000
        // --------------------------------------------------------------------
        send_and_capture(5'd0, 5'd4, 5'd8, 10'd40, 3'b010, 3'b010, 3'd0);
        check_pulse_count(4, "4 instr_valid pulses");
        check_pulse(0, 5'd0, 5'd4, 5'd8,  8'b11111111, 1'b0,
                    "pulse 0: mask=11111111  last=0");
        check_pulse(1, 5'd1, 5'd5, 5'd9,  8'b11111111, 1'b0,
                    "pulse 1: mask=11111111  last=0");
        check_pulse(2, 5'd2, 5'd6, 5'd10, 8'b00001111, 1'b0,
                    "pulse 2: mask=00001111  (lanes 4-7 tail)  last=0");
        check_pulse(3, 5'd3, 5'd7, 5'd11, 8'b00000000, 1'b1,
                    "pulse 3: mask=00000000  (all tail)  last=1");
        suite_end();

        // --------------------------------------------------------------------
        suite_start("SUITE 6: LMUL=8  eew=64  vl=64  (eight full registers)");
        // expect: 8 pulses, all masks 11111111, addresses 0-7
        // --------------------------------------------------------------------
        send_and_capture(5'd0, 5'd8, 5'd16, 10'd64, 3'b011, 3'b011, 3'd0);
        check_pulse_count(8, "8 instr_valid pulses");
        check_pulse(0, 5'd0,  5'd8,  5'd16, 8'b11111111, 1'b0, "pulse 0: vs1=0  last=0");
        check_pulse(1, 5'd1,  5'd9,  5'd17, 8'b11111111, 1'b0, "pulse 1: vs1=1  last=0");
        check_pulse(2, 5'd2,  5'd10, 5'd18, 8'b11111111, 1'b0, "pulse 2: vs1=2  last=0");
        check_pulse(3, 5'd3,  5'd11, 5'd19, 8'b11111111, 1'b0, "pulse 3: vs1=3  last=0");
        check_pulse(4, 5'd4,  5'd12, 5'd20, 8'b11111111, 1'b0, "pulse 4: vs1=4  last=0");
        check_pulse(5, 5'd5,  5'd13, 5'd21, 8'b11111111, 1'b0, "pulse 5: vs1=5  last=0");
        check_pulse(6, 5'd6,  5'd14, 5'd22, 8'b11111111, 1'b0, "pulse 6: vs1=6  last=0");
        check_pulse(7, 5'd7,  5'd15, 5'd23, 8'b11111111, 1'b1, "pulse 7: vs1=7  last=1");
        suite_end();

        // --------------------------------------------------------------------
        suite_start("SUITE 7: back-to-back instructions");
        // Two LMUL=1 instructions fired immediately after each other.
        // seq_busy must fall and rise cleanly between them.
        // --------------------------------------------------------------------
        send_and_capture(5'd1, 5'd2, 5'd3, 10'd8, 3'b011, 3'b000, 3'd1);  // SUB
        check_pulse_count(1, "instr A: 1 pulse");
        check_pulse(0, 5'd1, 5'd2, 5'd3, 8'b11111111, 1'b1,
                    "instr A: vs1=1 vs2=2 vd=3  mask=11111111  last=1");

        send_and_capture(5'd4, 5'd5, 5'd6, 10'd8, 3'b011, 3'b000, 3'd2);  // OR
        check_pulse_count(1, "instr B: 1 pulse");
        check_pulse(0, 5'd4, 5'd5, 5'd6, 8'b11111111, 1'b1,
                    "instr B: vs1=4 vs2=5 vd=6  mask=11111111  last=1");
        suite_end();

        // --------------------------------------------------------------------
        suite_start("SUITE 8: fractional LMUL=1/2  eew=64  vl=4");
        // vlmul=3'b111 -> lmul_fractional=1, reg_group_size=1 -> 1 pulse
        // vl=4 -> lanes 0-3 active, lanes 4-7 tail -> mask=00001111
        // --------------------------------------------------------------------
        send_and_capture(5'd2, 5'd4, 5'd6, 10'd4, 3'b011, 3'b111, 3'd0);
        check_pulse_count(1, "1 pulse (fractional LMUL acts as LMUL=1)");
        check_pulse(0, 5'd2, 5'd4, 5'd6, 8'b00001111, 1'b1,
                    "pulse 0: mask=00001111  last=1");
        suite_end();

        // --------------------------------------------------------------------
        $display("\n================================================================================");
        $display("  SUMMARY");
        $display("================================================================================");
        $display("  Total  : %0d", total_tests);
        $display("  Passed : %0d", passed_tests);
        $display("  Failed : %0d", failed_tests);
        $display("  Rate   : %.2f%%", (passed_tests * 100.0) / total_tests);
        $display("================================================================================");
        if (failed_tests == 0)
            $display("  *** ALL TESTS PASSED ***");
        else
            $display("  *** %0d TESTS FAILED ***", failed_tests);
        $display("================================================================================\n");

        $finish;
    end

    // =========================================================================
    // Waveform dump
    // =========================================================================
    initial begin
        $dumpfile("micro_sequencer_tb.vcd");
        $dumpvars(0, micro_sequencer_tb);
    end

endmodule