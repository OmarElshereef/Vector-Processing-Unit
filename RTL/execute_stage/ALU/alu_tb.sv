`timescale 1ns/1ps

module addModule_tb;

    //========================================================================
    // Parameters
    //========================================================================
    localparam NUM_RANDOM_TESTS = 50;
    localparam LENGTH      = 32;
    localparam SUB_LENGTH  = 8;
    localparam ELEN_WIDTH  = $clog2($clog2(LENGTH/SUB_LENGTH) + 1);
    localparam FINAL_WIDTH = (ELEN_WIDTH < 1) ? 1 : ELEN_WIDTH;
    localparam MAX_ELEN    = $clog2(LENGTH/SUB_LENGTH);  // 2 for 32/8

    // Suppress parameter name collision ? redefine cleanly
    localparam FW = (ELEN_WIDTH < 1) ? 1 : ELEN_WIDTH;

    //========================================================================
    // DUT Signals
    //========================================================================
    reg        clk;
    reg  [2:0] mode;
    reg  [FW:0] elen;
    reg  [LENGTH-1:0] op1, op2;
    reg        carry_in;
    wire [LENGTH-1:0] out;
    wire       carry;

    //========================================================================
    // DUT
    //========================================================================
    addModule #(
        .LENGTH     (LENGTH),
        .SUB_LENGTH (SUB_LENGTH)
    ) dut (
        .mode     (mode),
        .elen     (elen),
        .op1      (op1),
        .op2      (op2),
        .carry_in (carry_in),
        .out      (out),
        .carry    (carry)
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
    // Computes expected ADD/SUB result and carry with carry_in injected
    // carry_in seeds the very first unit of the first element
    //========================================================================
    function automatic [LENGTH-1:0] ref_add_sub;
        input [LENGTH-1:0] a1, a2;
        input              is_sub;
        input integer      elen_in;
        input              cin;        // injected carry_in
        integer elem, u, bit_idx;
        integer element_size, num_elements;
        reg [LENGTH-1:0] rf, op2_mod;
        reg              c;
        reg [31:0]       s1, s2, sum;
    begin
        element_size = SUB_LENGTH * (1 << elen_in);
        num_elements = LENGTH / element_size;
        rf      = 0;
        op2_mod = is_sub ? ~a2 : a2;
        for (elem = 0; elem < num_elements; elem = elem + 1) begin
            // first element gets cin, subsequent elements restart
            // at is_sub (matching addModule boundary logic)
            c = (elem == 0) ? cin : is_sub;
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

    function automatic ref_carry;
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
        // carry output is from the LAST element only
        element_size     = SUB_LENGTH * (1 << elen_in);
        last_elem_start  = LENGTH - element_size;
        op2_mod          = is_sub ? ~a2 : a2;
        // last element always restarts at is_sub (not cin)
        // unless it IS the first element (num_elements==1)
        c = (LENGTH == element_size) ? cin : is_sub;
        for (u = 0; u < (1 << elen_in); u = u + 1) begin
            bit_idx = last_elem_start + u * SUB_LENGTH;
            s1  = (a1      >> bit_idx) & ((1 << SUB_LENGTH) - 1);
            s2  = (op2_mod >> bit_idx) & ((1 << SUB_LENGTH) - 1);
            sum = s1 + s2 + c;
            c   = (sum >> SUB_LENGTH) & 1'b1;
        end
        ref_carry = c ^ is_sub;
    end
    endfunction

    //========================================================================
    // Core Check Task ? combinational DUT, sample after #1
    //========================================================================
    task check;
        input [2:0]       test_mode;
        input integer     elen_val;
        input [LENGTH-1:0] operand1, operand2;
        input             cin;
        input [LENGTH-1:0] exp_out;
        input             exp_carry;
        input string      test_name;
        reg [LENGTH-1:0]  got_out;
        reg               got_carry;
    begin
        mode     = test_mode;
        elen     = elen_val;
        op1      = operand1;
        op2      = operand2;
        carry_in = cin;
        #1; // combinational settle
        got_out   = out;
        got_carry = carry;

        total_tests = total_tests + 1;
        if (got_out === exp_out &&
            (test_mode > 3'd1 || got_carry === exp_carry)) begin
            passed_tests = passed_tests + 1;
            suite_pass   = suite_pass + 1;
            $display("[PASS] %s", test_name);
        end else begin
            failed_tests = failed_tests + 1;
            suite_fail   = suite_fail + 1;
            $display("[FAIL] %s", test_name);
            $display("  Mode=%s elen=%0d cin=%b",
                (test_mode==0)?"ADD":(test_mode==1)?"SUB":
                (test_mode==2)?"OR" :(test_mode==3)?"AND":
                (test_mode==4)?"NOT":"XOR", elen_val, cin);
            $display("  op1     : 0x%08h", operand1);
            $display("  op2     : 0x%08h", operand2);
            $display("  Expected: 0x%08h  carry=%b", exp_out, exp_carry);
            $display("  Got     : 0x%08h  carry=%b", got_out, got_carry);
        end
    end
    endtask

    // Shorthand for ADD/SUB using reference model
    task check_arith;
        input [2:0]       test_mode;
        input integer     elen_val;
        input [LENGTH-1:0] a1, a2;
        input             cin;
        input string      name;
        reg [LENGTH-1:0]  exp;
        reg               expc;
    begin
        exp  = ref_add_sub(a1, a2, (test_mode==1), elen_val, cin);
        expc = ref_carry  (a1, a2, (test_mode==1), elen_val, cin);
        check(test_mode, elen_val, a1, a2, cin, exp, expc, name);
    end
    endtask

    // Shorthand for logical ops (carry_in irrelevant)
    task check_logic;
        input [2:0]       test_mode;
        input [LENGTH-1:0] a1, a2;
        input string      name;
        reg [LENGTH-1:0]  exp;
    begin
        case (test_mode)
            3'd2: exp = a1 | a2;
            3'd3: exp = a1 & a2;
            3'd4: exp = ~a1;
            3'd5: exp = a1 ^ a2;
            default: exp = 0;
        endcase
        check(test_mode, 0, a1, a2, 0, exp, 0, name);
    end
    endtask

    //========================================================================
    // Main
    //========================================================================
    integer i, el;
    reg [LENGTH-1:0] ra, rb;

    initial begin
        $display("================================================================================");
        $display("  addModule Testbench ? with carry_in");
        $display("  LENGTH=%0d SUB_LENGTH=%0d MAX_ELEN=%0d", LENGTH, SUB_LENGTH, MAX_ELEN);
        $display("================================================================================");

        mode = 0; elen = 0; op1 = 0; op2 = 0; carry_in = 0;
        #10;

        //====================================================================
        suite_start("SUITE 1: ADD ? carry_in=0 (baseline, no incoming carry)");
        //====================================================================
        for (el = 0; el <= MAX_ELEN; el = el + 1) begin
            check_arith(0, el, 32'h12345678, 32'h87654321, 0,
                $sformatf("ADD cin=0 elen=%0d: 0x12345678+0x87654321", el));
            check_arith(0, el, 32'hFFFFFFFF, 32'h00000001, 0,
                $sformatf("ADD cin=0 elen=%0d: all-ones+1 overflow", el));
            check_arith(0, el, 32'h00000000, 32'h00000000, 0,
                $sformatf("ADD cin=0 elen=%0d: 0+0", el));
            check_arith(0, el, 32'hAAAAAAAA, 32'h55555555, 0,
                $sformatf("ADD cin=0 elen=%0d: AAAA+5555", el));
        end
        suite_end();

        //====================================================================
        suite_start("SUITE 2: ADD ? carry_in=1 (incoming carry from previous lane)");
        //====================================================================
        // carry_in=1 should add 1 to the result of the first element
        for (el = 0; el <= MAX_ELEN; el = el + 1) begin
            // 0+0+cin=1 ? result=1, no carry out
            check_arith(0, el, 32'h00000000, 32'h00000000, 1,
                $sformatf("ADD cin=1 elen=%0d: 0+0+1=1", el));
            // all-ones+0+cin=1 ? overflow, result=0
            check_arith(0, el, 32'hFFFFFFFF, 32'h00000000, 1,
                $sformatf("ADD cin=1 elen=%0d: all-ones+0+1=overflow", el));
            // 0x7FFFFFFF+0+1 = 0x80000000 (sign bit flips)
            check_arith(0, el, 32'h7FFFFFFF, 32'h00000000, 1,
                $sformatf("ADD cin=1 elen=%0d: 0x7FFFFFFF+cin", el));
            check_arith(0, el, 32'h12345678, 32'h87654321, 1,
                $sformatf("ADD cin=1 elen=%0d: normal+cin", el));
        end

        // Key: verify carry_in only affects FIRST element, not others
        // With elen=0 (8-bit elements): first element gets cin, rest restart at 0
        // With elen=2 (32-bit, full width): entire word gets cin
        check_arith(0, 0, 32'hFFFFFF00, 32'h00000000, 1,
            "ADD cin=1 elen=0: cin only affects first 8-bit element");
        check_arith(0, 1, 32'hFFFF0000, 32'h00000000, 1,
            "ADD cin=1 elen=1: cin only affects first 16-bit element");
        check_arith(0, 2, 32'hFFFFFFFF, 32'h00000000, 1,
            "ADD cin=1 elen=2: cin propagates through full 32-bit word");
        suite_end();

        //====================================================================
        suite_start("SUITE 3: SUB ? carry_in=1 (normal: borrow init for first lane)");
        //====================================================================
        // For SUB, carry_in=1 is the normal case ? it's the initial borrow
        // that makes two's complement work. The reference model handles this.
        for (el = 0; el <= MAX_ELEN; el = el + 1) begin
            check_arith(1, el, 32'h87654321, 32'h12345678, 1,
                $sformatf("SUB cin=1 elen=%0d: 0x87654321-0x12345678", el));
            check_arith(1, el, 32'hFFFFFFFF, 32'hFFFFFFFF, 1,
                $sformatf("SUB cin=1 elen=%0d: all-ones - all-ones = 0", el));
            check_arith(1, el, 32'h00000000, 32'h00000001, 1,
                $sformatf("SUB cin=1 elen=%0d: 0 - 1 underflow", el));
            check_arith(1, el, 32'h00000001, 32'h00000001, 1,
                $sformatf("SUB cin=1 elen=%0d: 1 - 1 = 0", el));
        end
        suite_end();

        //====================================================================
        suite_start("SUITE 4: SUB ? carry_in=0 (chained borrow from previous lane)");
        //====================================================================
        // carry_in=0 for SUB means a borrow was consumed by the previous lane
        // so this lane's first element does NOT get the normal initial borrow
        // This is the chained case when a multi-lane subtraction propagates borrow
        for (el = 0; el <= MAX_ELEN; el = el + 1) begin
            check_arith(1, el, 32'h00000000, 32'h00000000, 0,
                $sformatf("SUB cin=0 elen=%0d: 0-0 with consumed borrow", el));
            check_arith(1, el, 32'hFFFFFFFF, 32'h00000000, 0,
                $sformatf("SUB cin=0 elen=%0d: all-ones-0 with consumed borrow", el));
            check_arith(1, el, 32'h12345678, 32'h87654321, 0,
                $sformatf("SUB cin=0 elen=%0d: normal with consumed borrow", el));
        end
        suite_end();

        //====================================================================
        suite_start("SUITE 5: Carry Output Verification");
        //====================================================================
        // ADD carry_out: all-ones+1 should produce carry=1
        check_arith(0, MAX_ELEN, 32'hFFFFFFFF, 32'h00000001, 0,
            "ADD carry_out=1: all-ones+1");
        check_arith(0, MAX_ELEN, 32'hFFFFFFFF, 32'h00000000, 1,
            "ADD carry_out=1: all-ones+cin=1");
        check_arith(0, MAX_ELEN, 32'h7FFFFFFF, 32'h00000001, 0,
            "ADD carry_out=0: 0x7FFFFFFF+1 no carry");
        check_arith(0, MAX_ELEN, 32'h00000000, 32'h00000000, 0,
            "ADD carry_out=0: 0+0");

        // SUB carry_out: normalised ? 1 means no borrow, 0 means borrow
        check_arith(1, MAX_ELEN, 32'hFFFFFFFF, 32'h00000001, 1,
            "SUB carry_out=1 (no borrow): all-ones-1");
        check_arith(1, MAX_ELEN, 32'h00000000, 32'h00000001, 1,
            "SUB carry_out=0 (borrow): 0-1");
        check_arith(1, MAX_ELEN, 32'h00000001, 32'h00000001, 1,
            "SUB carry_out=1: 1-1=0 no borrow");

        // Carry output with elen<MAX: carry is from LAST element boundary only
        // With elen=0 (8-bit elements): only last 8-bit chunk can set carry
        check_arith(0, 0, 32'hFF000000, 32'h01000000, 0,
            "ADD elen=0: carry from last 8-bit element (upper byte overflow)");
        check_arith(0, 0, 32'h00FFFFFF, 32'h00000001, 0,
            "ADD elen=0: no carry from last 8-bit element");
        suite_end();

        //====================================================================
        suite_start("SUITE 6: Carry Boundary Isolation ? cin must not bleed");
        //====================================================================
        // When elen=0 (8-bit independent elements), carry_in seeds only the
        // first 8-bit element. The boundary restart must block it from element 2+.
        // Test: first element overflows with cin, second element must not be affected

        // elen=0: 4 independent 8-bit elements in 32-bit word
        // With cin=1, first element (bits 7:0) = 0xFF+0x00+1 = 0x00 + carry
        // Second element (bits 15:8) restarts fresh, should see 0xFF+0x00+0 = 0xFF
        check_arith(0, 0, 32'hFFFFFFFF, 32'h00000000, 1,
            "Boundary: cin=1 elen=0: only first byte gets cin");
        check_arith(0, 0, 32'hFF000000, 32'h00000000, 1,
            "Boundary: cin=1 elen=0: upper bytes unaffected by cin");

        // elen=1: 2 independent 16-bit elements
        check_arith(0, 1, 32'hFFFFFFFF, 32'h00000000, 1,
            "Boundary: cin=1 elen=1: only first halfword gets cin");
        check_arith(0, 1, 32'hFFFF0000, 32'h00000000, 1,
            "Boundary: cin=1 elen=1: upper halfword unaffected by cin");

        // elen=2: single 32-bit element ? cin propagates all the way through
        check_arith(0, 2, 32'hFFFFFFFF, 32'h00000000, 1,
            "Boundary: cin=1 elen=2: full word, cin propagates through all");
        suite_end();

        //====================================================================
        suite_start("SUITE 7: Logical Ops ? carry_in must be ignored");
        //====================================================================
        // Logical ops should produce identical results regardless of carry_in
        for (i = 0; i < 20; i = i + 1) begin
            ra = $random;
            rb = $random;
            // check with cin=0
            check(3'd2, 0, ra, rb, 0, ra|rb, 0, $sformatf("OR  cin=0 random #%0d", i));
            check(3'd3, 0, ra, rb, 0, ra&rb, 0, $sformatf("AND cin=0 random #%0d", i));
            check(3'd4, 0, ra, rb, 0, ~ra,   0, $sformatf("NOT cin=0 random #%0d", i));
            check(3'd5, 0, ra, rb, 0, ra^rb, 0, $sformatf("XOR cin=0 random #%0d", i));
            // same operands with cin=1 ? result must be identical
            check(3'd2, 0, ra, rb, 1, ra|rb, 0, $sformatf("OR  cin=1 random #%0d", i));
            check(3'd3, 0, ra, rb, 1, ra&rb, 0, $sformatf("AND cin=1 random #%0d", i));
            check(3'd4, 0, ra, rb, 1, ~ra,   0, $sformatf("NOT cin=1 random #%0d", i));
            check(3'd5, 0, ra, rb, 1, ra^rb, 0, $sformatf("XOR cin=1 random #%0d", i));
        end
        suite_end();

        //====================================================================
        suite_start("SUITE 8: Original Operations ? Regression");
        //====================================================================
        // Make sure existing functionality still works with cin=0/1

        // ADD regression
        check_arith(0, 0, 32'h12345678, 32'h87654321, 0, "ADD elen=0 regression");
        check_arith(0, 1, 32'h12345678, 32'h87654321, 0, "ADD elen=1 regression");
        check_arith(0, 2, 32'h12345678, 32'h87654321, 0, "ADD elen=2 regression");

        // SUB regression
        check_arith(1, 0, 32'h87654321, 32'h12345678, 1, "SUB elen=0 regression");
        check_arith(1, 1, 32'h87654321, 32'h12345678, 1, "SUB elen=1 regression");
        check_arith(1, 2, 32'h87654321, 32'h12345678, 1, "SUB elen=2 regression");

        // Logical regression
        check_logic(3'd2, 32'h0F0F0F0F, 32'hF0F0F0F0, "OR  regression");
        check_logic(3'd3, 32'h0F0F0F0F, 32'hF0F0F0F0, "AND regression");
        check_logic(3'd4, 32'h12345678, 32'h00000000, "NOT regression");
        check_logic(3'd5, 32'h0F0F0F0F, 32'hF0F0F0F0, "XOR regression");
        suite_end();

        //====================================================================
        suite_start("SUITE 9: Random Tests ? All modes, all elen, random cin");
        //====================================================================
        for (i = 0; i < NUM_RANDOM_TESTS; i = i + 1) begin
            ra = $random;
            rb = $random;
            for (el = 0; el <= MAX_ELEN; el = el + 1) begin
                // ADD cin=0
                check_arith(0, el, ra, rb, 0,
                    $sformatf("Random ADD cin=0 elen=%0d #%0d", el, i));
                // ADD cin=1
                check_arith(0, el, ra, rb, 1,
                    $sformatf("Random ADD cin=1 elen=%0d #%0d", el, i));
                // SUB cin=1 (normal)
                check_arith(1, el, ra, rb, 1,
                    $sformatf("Random SUB cin=1 elen=%0d #%0d", el, i));
                // SUB cin=0 (chained borrow)
                check_arith(1, el, ra, rb, 0,
                    $sformatf("Random SUB cin=0 elen=%0d #%0d", el, i));
            end
            // Logical with random cin ? result must match regardless
            check(3'd2, 0, ra, rb, $random&1, ra|rb, 0,
                $sformatf("Random OR  #%0d", i));
            check(3'd3, 0, ra, rb, $random&1, ra&rb, 0,
                $sformatf("Random AND #%0d", i));
            check(3'd4, 0, ra, rb, $random&1, ~ra,   0,
                $sformatf("Random NOT #%0d", i));
            check(3'd5, 0, ra, rb, $random&1, ra^rb, 0,
                $sformatf("Random XOR #%0d", i));
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
        $dumpfile("addModule_tb.vcd");
        $dumpvars(0, addModule_tb);
    end

endmodule