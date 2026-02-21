`timescale 1ns/1ps

module executeLane_tb;

    //========================================================================
    // Parameters
    //========================================================================
    localparam NUM_RANDOM_TESTS = 50;
    localparam LENGTH      = 64;
    localparam SUB_LENGTH  = 16;
    localparam ELEN_WIDTH  = $clog2($clog2(LENGTH/SUB_LENGTH) + 1);
    localparam FINAL_WIDTH = (ELEN_WIDTH < 1) ? 1 : ELEN_WIDTH;
    localparam MAX_ELEN    = $clog2(LENGTH/SUB_LENGTH); // 2 for 64/16

    //========================================================================
    // Opcodes
    //========================================================================
    localparam ADD = 3'd0;
    localparam SUB = 3'd1;
    localparam OR  = 3'd2;
    localparam AND = 3'd3;
    localparam NOT = 3'd4;
    localparam XOR = 3'd5;

    //========================================================================
    // DUT Signals
    //========================================================================
    reg                  clk;
    reg                  latch_en;
    reg                  chained_carry;
    reg  [FINAL_WIDTH:0] elen;
    reg  [LENGTH-1:0]    operand;
    reg  [2:0]           opcode;
    wire [LENGTH-1:0]    result;      // combinational wire ? valid same cycle as op2
    wire                 carry_out;

    //========================================================================
    // DUT
    //========================================================================
    executeLane #(
        .LENGTH      (LENGTH),
        .SUB_LENGTH  (SUB_LENGTH),
        .ELEN_WIDTH  (ELEN_WIDTH),
        .FINAL_WIDTH (FINAL_WIDTH)
    ) dut (
        .clk           (clk),
        .latch_en      (latch_en),
        .chained_carry (chained_carry),
        .elen          (elen),
        .operand       (operand),
        .opcode        (opcode),
        .result        (result),
        .carry_out     (carry_out)
    );

    //========================================================================
    // Clock
    //========================================================================
    initial begin clk = 0; forever #5 clk = ~clk; end

    //========================================================================
    // Statistics
    //========================================================================
    integer total_tests  = 0;
    integer passed_tests = 0;
    integer failed_tests = 0;
    integer suite_pass, suite_fail;

    task suite_start;
        input string name;
    begin
        suite_pass = 0; suite_fail = 0;
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

    //========================================================================
    // Reference Model
    //========================================================================

    function automatic [LENGTH-1:0] ref_add_sub;
        input [LENGTH-1:0] a1, a2;
        input              is_sub;
        input integer      elen_in;
        input              cin;
        integer elem, u, bit_idx;
        integer element_size, num_elements;
        reg [LENGTH-1:0] rf, op2_mod;
        reg              c;
        reg [31:0]       s1, s2, sum;
    begin
        element_size  = SUB_LENGTH * (1 << elen_in);
        num_elements  = LENGTH / element_size;
        rf      = 0;
        op2_mod = is_sub ? ~a2 : a2;
        for (elem = 0; elem < num_elements; elem = elem + 1) begin
            c = (elem == 0) ? cin : is_sub; // only first element gets cin
            for (u = 0; u < (1 << elen_in); u = u + 1) begin
                bit_idx = elem * element_size + u * SUB_LENGTH;
                s1  = (a1      >> bit_idx) & ((1 << SUB_LENGTH) - 1);
                s2  = (op2_mod >> bit_idx) & ((1 << SUB_LENGTH) - 1);
                sum = s1 + s2 + c;
                c   = (sum >> SUB_LENGTH) & 1'b1;
                rf  = rf | (((sum & ((1 << SUB_LENGTH) - 1)) << bit_idx));
            end
        end
        ref_add_sub = rf;
    end
    endfunction

    function automatic ref_carry_out;
        input [LENGTH-1:0] a1, a2;
        input              is_sub;
        input integer      elen_in;
        input              cin;
        integer u, bit_idx;
        integer element_size;
        integer last_elem_start;
        reg [LENGTH-1:0] op2_mod;
        reg              c;
        reg [31:0]       s1, s2, sum;
    begin
        element_size     = SUB_LENGTH * (1 << elen_in);
        last_elem_start  = LENGTH - element_size;
        op2_mod          = is_sub ? ~a2 : a2;
        // last element restarts at is_sub unless it IS the first element
        c = (LENGTH == element_size) ? cin : is_sub;
        for (u = 0; u < (1 << elen_in); u = u + 1) begin
            bit_idx = last_elem_start + u * SUB_LENGTH;
            s1  = (a1      >> bit_idx) & ((1 << SUB_LENGTH) - 1);
            s2  = (op2_mod >> bit_idx) & ((1 << SUB_LENGTH) - 1);
            sum = s1 + s2 + c;
            c   = (sum >> SUB_LENGTH) & 1'b1;
        end
        ref_carry_out = c ^ is_sub;
    end
    endfunction

    function automatic [LENGTH-1:0] ref_logical;
        input [LENGTH-1:0] a1, a2;
        input [2:0]        op;
    begin
        case (op)
            OR:  ref_logical = a1 | a2;
            AND: ref_logical = a1 & a2;
            XOR: ref_logical = a1 ^ a2;
            NOT: ref_logical = ~a1;
            default: ref_logical = 0;
        endcase
    end
    endfunction

    //========================================================================
    // Core Execute Task
    //
    // Pipeline (updated ? result is combinational wire):
    //   Cycle 1 posedge: latch_en=1, operand=op1 ? op_latch captures op1
    //   Cycle 2 posedge: latch_en=0, operand=op2 ? ALU fires with op_latch+op2
    //   #1 after cycle 2: result and carry_out are stable (combinational)
    //========================================================================
    task run_test;
        input [LENGTH-1:0]    op1;
        input [LENGTH-1:0]    op2;
        input [2:0]           op;
        input [FINAL_WIDTH:0] el;
        input                 cin;
        input [LENGTH-1:0]    expected_result;
        input                 expected_carry;
        input string          test_name;
        reg [LENGTH-1:0]      got_result;
        reg                   got_carry;
    begin
        // Cycle 1: latch op1
        @(posedge clk);
        opcode        = op;
        elen          = el;
        operand       = op1;
        latch_en      = 1;
        chained_carry = cin;

        // Cycle 2: present op2, ALU fires combinationally
        @(posedge clk);
        operand  = op2;
        latch_en = 0;
        #1; // combinational settle ? result valid NOW, no extra clock needed

        got_result = result;
        got_carry  = carry_out;

        total_tests = total_tests + 1;
        if (got_result === expected_result &&
            (op > SUB || got_carry === expected_carry)) begin
            passed_tests = passed_tests + 1;
            suite_pass   = suite_pass + 1;
            $display("[PASS] %s", test_name);
        end else begin
            failed_tests = failed_tests + 1;
            suite_fail   = suite_fail + 1;
            $display("[FAIL] %s", test_name);
            $display("  Op     : %s  ELEN=%0d  cin=%b",
                     (op==ADD)?"ADD":(op==SUB)?"SUB":(op==OR)?"OR":
                     (op==AND)?"AND":(op==NOT)?"NOT":(op==XOR)?"XOR":"???",
                     el, cin);
            $display("  op1    : 0x%016h", op1);
            $display("  op2    : 0x%016h", op2);
            $display("  Expect : 0x%016h  carry=%b", expected_result, expected_carry);
            $display("  Got    : 0x%016h  carry=%b", got_result, got_carry);
        end
    end
    endtask

    // Shorthand: auto-compute expected from reference model
    task run_arith;
        input [LENGTH-1:0]    op1, op2;
        input [2:0]           op;
        input [FINAL_WIDTH:0] el;
        input                 cin;
        input string          name;
        reg [LENGTH-1:0]      exp;
        reg                   expc;
    begin
        exp  = ref_add_sub  (op1, op2, (op==SUB), el, cin);
        expc = ref_carry_out(op1, op2, (op==SUB), el, cin);
        run_test(op1, op2, op, el, cin, exp, expc, name);
    end
    endtask

    task run_logic;
        input [LENGTH-1:0] op1, op2;
        input [2:0]        op;
        input string       name;
        reg [LENGTH-1:0]   exp;
    begin
        exp = ref_logical(op1, op2, op);
        run_test(op1, op2, op, 0, 0, exp, 0, name);
    end
    endtask

    //========================================================================
    // Main
    //========================================================================
    integer i, el;
    reg [LENGTH-1:0] r1, r2;

    initial begin
        $display("================================================================================");
        $display("  executeLane Testbench ? with chained_carry, combinational result");
        $display("  LENGTH=%0d  SUB_LENGTH=%0d  MAX_ELEN=%0d", LENGTH, SUB_LENGTH, MAX_ELEN);
        $display("================================================================================");

        latch_en      = 0;
        chained_carry = 0;
        elen          = 0;
        operand       = 0;
        opcode        = 0;
        repeat(2) @(posedge clk);

        //====================================================================
        suite_start("SUITE 1: ADD ? chained_carry=0 (no incoming carry)");
        //====================================================================
        for (el = 0; el <= MAX_ELEN; el = el + 1) begin
            run_arith(64'h123456789ABCDEF0, 64'hFEDCBA9876543210,
                      ADD, el, 0, $sformatf("ADD cin=0 elen=%0d: mixed", el));
            run_arith(64'hFFFFFFFFFFFFFFFF, 64'h0000000000000001,
                      ADD, el, 0, $sformatf("ADD cin=0 elen=%0d: overflow", el));
            run_arith(64'hAAAAAAAAAAAAAAAA, 64'h5555555555555555,
                      ADD, el, 0, $sformatf("ADD cin=0 elen=%0d: AAAA+5555", el));
            run_arith(64'h0000000000000000, 64'h0000000000000000,
                      ADD, el, 0, $sformatf("ADD cin=0 elen=%0d: 0+0", el));
        end
        suite_end();

        //====================================================================
        suite_start("SUITE 2: ADD ? chained_carry=1 (incoming carry from previous lane)");
        //====================================================================
        for (el = 0; el <= MAX_ELEN; el = el + 1) begin
            run_arith(64'h0000000000000000, 64'h0000000000000000,
                      ADD, el, 1, $sformatf("ADD cin=1 elen=%0d: 0+0+1=1", el));
            run_arith(64'hFFFFFFFFFFFFFFFF, 64'h0000000000000000,
                      ADD, el, 1, $sformatf("ADD cin=1 elen=%0d: all-ones+cin overflow", el));
            run_arith(64'h7FFFFFFFFFFFFFFF, 64'h0000000000000000,
                      ADD, el, 1, $sformatf("ADD cin=1 elen=%0d: 0x7FFF...+cin", el));
            run_arith(64'h123456789ABCDEF0, 64'hFEDCBA9876543210,
                      ADD, el, 1, $sformatf("ADD cin=1 elen=%0d: mixed+cin", el));
        end

        // cin only seeds first element ? verify boundary isolation
        run_arith(64'hFFFFFFFFFFFF0000, 64'h0000000000000000,
                  ADD, 0, 1, "ADD cin=1 elen=0: cin seeds first 16-bit only");
        run_arith(64'hFFFFFFFF00000000, 64'h0000000000000000,
                  ADD, 1, 1, "ADD cin=1 elen=1: cin seeds first 32-bit only");
        run_arith(64'hFFFFFFFFFFFFFFFF, 64'h0000000000000000,
                  ADD, 2, 1, "ADD cin=1 elen=2: cin propagates full 64-bit");
        suite_end();

        //====================================================================
        suite_start("SUITE 3: SUB ? chained_carry=1 (normal initial borrow)");
        //====================================================================
        for (el = 0; el <= MAX_ELEN; el = el + 1) begin
            run_arith(64'hFEDCBA9876543210, 64'h123456789ABCDEF0,
                      SUB, el, 1, $sformatf("SUB cin=1 elen=%0d: mixed", el));
            run_arith(64'hFFFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFF,
                      SUB, el, 1, $sformatf("SUB cin=1 elen=%0d: x-x=0", el));
            run_arith(64'h0000000000000000, 64'h0000000000000001,
                      SUB, el, 1, $sformatf("SUB cin=1 elen=%0d: 0-1 underflow", el));
            run_arith(64'h0000000000000001, 64'h0000000000000001,
                      SUB, el, 1, $sformatf("SUB cin=1 elen=%0d: 1-1=0", el));
        end
        suite_end();

        //====================================================================
        suite_start("SUITE 4: SUB ? chained_carry=0 (consumed borrow from prev lane)");
        //====================================================================
        for (el = 0; el <= MAX_ELEN; el = el + 1) begin
            run_arith(64'h0000000000000000, 64'h0000000000000000,
                      SUB, el, 0, $sformatf("SUB cin=0 elen=%0d: 0-0 no borrow", el));
            run_arith(64'hFFFFFFFFFFFFFFFF, 64'h0000000000000000,
                      SUB, el, 0, $sformatf("SUB cin=0 elen=%0d: all-ones-0 no borrow", el));
            run_arith(64'h123456789ABCDEF0, 64'hFEDCBA9876543210,
                      SUB, el, 0, $sformatf("SUB cin=0 elen=%0d: mixed no borrow", el));
        end
        suite_end();

        //====================================================================
        suite_start("SUITE 5: carry_out Verification");
        //====================================================================
        // ADD: all-ones+1 = overflow ? carry_out=1
        run_arith(64'hFFFFFFFFFFFFFFFF, 64'h0000000000000001,
                  ADD, MAX_ELEN, 0, "ADD carry_out=1: all-ones+1");
        run_arith(64'hFFFFFFFFFFFFFFFF, 64'h0000000000000000,
                  ADD, MAX_ELEN, 1, "ADD carry_out=1: all-ones+cin");
        run_arith(64'h7FFFFFFFFFFFFFFF, 64'h0000000000000001,
                  ADD, MAX_ELEN, 0, "ADD carry_out=0: no overflow");
        run_arith(64'h0000000000000000, 64'h0000000000000000,
                  ADD, MAX_ELEN, 0, "ADD carry_out=0: 0+0");

        // SUB: normalized ? 1=no borrow, 0=borrow
        run_arith(64'hFFFFFFFFFFFFFFFF, 64'h0000000000000001,
                  SUB, MAX_ELEN, 1, "SUB carry_out=1: no borrow");
        run_arith(64'h0000000000000000, 64'h0000000000000001,
                  SUB, MAX_ELEN, 1, "SUB carry_out=0: borrow");
        run_arith(64'h0000000000000001, 64'h0000000000000001,
                  SUB, MAX_ELEN, 1, "SUB carry_out=1: 1-1=0 no borrow");

        // carry_out from last element only when elen<MAX
        run_arith(64'hFF00000000000000, 64'h0100000000000000,
                  ADD, 0, 0, "carry_out elen=0: from last 16-bit element");
        run_arith(64'h00FFFFFFFFFFFFFF, 64'h0000000000000001,
                  ADD, 0, 0, "carry_out elen=0: no carry from last element");
        suite_end();

        //====================================================================
        suite_start("SUITE 6: Logical Ops ? carry_in must be ignored");
        //====================================================================
        // Same inputs, both cin=0 and cin=1 must give identical results
        for (i = 0; i < 20; i = i + 1) begin
            r1 = {$random,$random};
            r2 = {$random,$random};
            run_test(r1, r2, OR,  0, 0, r1|r2, 0, $sformatf("OR  cin=0 #%0d", i));
            run_test(r1, r2, OR,  0, 1, r1|r2, 0, $sformatf("OR  cin=1 #%0d", i));
            run_test(r1, r2, AND, 0, 0, r1&r2, 0, $sformatf("AND cin=0 #%0d", i));
            run_test(r1, r2, AND, 0, 1, r1&r2, 0, $sformatf("AND cin=1 #%0d", i));
            run_test(r1, r2, XOR, 0, 0, r1^r2, 0, $sformatf("XOR cin=0 #%0d", i));
            run_test(r1, r2, XOR, 0, 1, r1^r2, 0, $sformatf("XOR cin=1 #%0d", i));
            run_test(r1, r2, NOT, 0, 0, ~r1,   0, $sformatf("NOT cin=0 #%0d", i));
            run_test(r1, r2, NOT, 0, 1, ~r1,   0, $sformatf("NOT cin=1 #%0d", i));
        end
        suite_end();

        //====================================================================
        suite_start("SUITE 7: op_latch Stability ? latch_en timing");
        //====================================================================
        // Drive op1, assert latch_en for exactly one cycle
        // Then change operand to op2 ? op_latch must hold op1

        // Test: latch holds even if operand changes on same cycle as latch_en drops
        run_arith(64'hDEADBEEFCAFEBABE, 64'hCAFEBABEDEADBEEF,
                  ADD, MAX_ELEN, 0, "Latch hold: op1 stable after latch_en drops");

        // Test: new latch_en overwrites previous latch
        @(posedge clk);
        operand  = 64'hAAAAAAAAAAAAAAAA;
        latch_en = 1;
        @(posedge clk);
        operand  = 64'hBBBBBBBBBBBBBBBB; // overwrite before latch_en drops
        latch_en = 1;                       // hold latch_en ? should keep updating
        @(posedge clk);
        latch_en = 0;
        operand  = 64'h0000000000000000;
        #1;
        // op_latch should now hold 0xBBBB... not 0xAAAA...
        // verify by running NOT ? result = ~op_latch
        opcode   = NOT;
        elen     = MAX_ELEN;
        chained_carry = 0;
        #1;
        total_tests = total_tests + 1;
        if (result === ~64'hBBBBBBBBBBBBBBBB) begin
            passed_tests = passed_tests + 1;
            suite_pass   = suite_pass + 1;
            $display("[PASS] Latch overwrite: second latch_en correctly overwrites first");
        end else begin
            failed_tests = failed_tests + 1;
            suite_fail   = suite_fail + 1;
            $display("[FAIL] Latch overwrite: expected 0x%016h got 0x%016h",
                     ~64'hBBBBBBBBBBBBBBBB, result);
        end
        suite_end();

        //====================================================================
        suite_start("SUITE 8: All Opcodes x All ELEN ? Full Coverage");
        //====================================================================
        // Known pattern set
        for (el = 0; el <= MAX_ELEN; el = el + 1) begin
            run_arith(64'hF0F0F0F0F0F0F0F0, 64'h0F0F0F0F0F0F0F0F,
                      ADD, el, 0, $sformatf("F0F0+0F0F ADD elen=%0d", el));
            run_arith(64'hF0F0F0F0F0F0F0F0, 64'h0F0F0F0F0F0F0F0F,
                      SUB, el, 1, $sformatf("F0F0-0F0F SUB elen=%0d", el));
            run_logic(64'hF0F0F0F0F0F0F0F0, 64'h0F0F0F0F0F0F0F0F,
                      OR,  $sformatf("F0F0|0F0F OR  elen=%0d", el));
            run_logic(64'hF0F0F0F0F0F0F0F0, 64'h0F0F0F0F0F0F0F0F,
                      AND, $sformatf("F0F0&0F0F AND elen=%0d", el));
            run_logic(64'hF0F0F0F0F0F0F0F0, 64'h0F0F0F0F0F0F0F0F,
                      XOR, $sformatf("F0F0^0F0F XOR elen=%0d", el));
            run_logic(64'hF0F0F0F0F0F0F0F0, 64'h0,
                      NOT, $sformatf("~F0F0 NOT elen=%0d", el));
        end
        suite_end();

        //====================================================================
        suite_start("SUITE 9: Random Tests ? All modes, all elen, both cin values");
        //====================================================================
        for (i = 0; i < NUM_RANDOM_TESTS; i = i + 1) begin
            r1 = {$random,$random};
            r2 = {$random,$random};
            for (el = 0; el <= MAX_ELEN; el = el + 1) begin
                run_arith(r1, r2, ADD, el, 0,
                    $sformatf("Rand ADD cin=0 elen=%0d #%0d", el, i));
                run_arith(r1, r2, ADD, el, 1,
                    $sformatf("Rand ADD cin=1 elen=%0d #%0d", el, i));
                run_arith(r1, r2, SUB, el, 1,
                    $sformatf("Rand SUB cin=1 elen=%0d #%0d", el, i));
                run_arith(r1, r2, SUB, el, 0,
                    $sformatf("Rand SUB cin=0 elen=%0d #%0d", el, i));
            end
            run_logic(r1, r2, OR,  $sformatf("Rand OR  #%0d", i));
            run_logic(r1, r2, AND, $sformatf("Rand AND #%0d", i));
            run_logic(r1, r2, XOR, $sformatf("Rand XOR #%0d", i));
            run_logic(r1, 64'h0, NOT, $sformatf("Rand NOT #%0d", i));
        end
        suite_end();

        //====================================================================
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

    initial begin
        $dumpfile("executeLane_tb.vcd");
        $dumpvars(0, executeLane_tb);
    end

endmodule