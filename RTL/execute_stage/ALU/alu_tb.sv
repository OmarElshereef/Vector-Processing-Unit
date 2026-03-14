`timescale 1ns/1ps

module laneALU_tb;

    //========================================================================
    // Parameters
    //========================================================================
    localparam NUM_RANDOM_TESTS = 50;
    localparam LANE_WIDTH  = 64;      // Changed to 64-bit to match multiplier
    localparam UNIT_WIDTH  = 16;      // Changed to 16-bit units
    localparam SEW_BITS    = $clog2($clog2(LANE_WIDTH/UNIT_WIDTH) + 1);
    localparam FINAL_BITS  = (SEW_BITS < 1) ? 1 : SEW_BITS;
    localparam MAX_EEW_LOG2 = $clog2(LANE_WIDTH/UNIT_WIDTH);  // 2 for 64/16

    localparam FW = (SEW_BITS < 1) ? 1 : SEW_BITS;

    //========================================================================
    // DUT Signals
    //========================================================================
    reg        clk;
    reg  [2:0] opcode;
    reg  [FW:0] eew_log2;
    reg  [LANE_WIDTH-1:0] operand1, operand2;
    reg        carry_in;
    reg        is_signed;
    
    wire [LANE_WIDTH-1:0]   result;
    wire [2*LANE_WIDTH-1:0] result_wide;
    wire       carry_out;

    //========================================================================
    // DUT
    //========================================================================
    laneALU #(
        .LANE_WIDTH  (LANE_WIDTH),
        .UNIT_WIDTH  (UNIT_WIDTH)
    ) dut (
        .opcode      (opcode),
        .eew_log2    (eew_log2),
        .is_signed   (is_signed),
        .operand1    (operand1),
        .operand2    (operand2),
        .carry_in    (carry_in),
        .result      (result),
        .result_wide (result_wide),
        .carry_out   (carry_out)
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
        $display("\n================================================================================");
        $display("%s", name);
        $display("================================================================================");
    end
    endtask

    task suite_end;
    begin
        $display("  Suite: %0d passed, %0d failed", suite_pass, suite_fail);
    end
    endtask

    //========================================================================
    // Reference Model for ADD/SUB
    //========================================================================
    function automatic [LANE_WIDTH-1:0] ref_add_sub;
        input [LANE_WIDTH-1:0] a1, a2;
        input                  is_sub;
        input integer          elen_in;
        input                  cin;
        integer elem, u, bit_idx;
        integer element_size, num_elements;
        reg [LANE_WIDTH-1:0] rf, op2_mod;
        reg              c;
        reg [63:0]       s1, s2, sum;
    begin
        element_size = UNIT_WIDTH * (1 << elen_in);
        num_elements = LANE_WIDTH / element_size;
        rf      = 0;
        op2_mod = is_sub ? ~a2 : a2;
        for (elem = 0; elem < num_elements; elem = elem + 1) begin
            c = (elem == 0) ? cin : is_sub;
            for (u = 0; u < (1 << elen_in); u = u + 1) begin
                bit_idx = elem * element_size + u * UNIT_WIDTH;
                s1  = (a1      >> bit_idx) & ((1 << UNIT_WIDTH) - 1);
                s2  = (op2_mod >> bit_idx) & ((1 << UNIT_WIDTH) - 1);
                sum = s1 + s2 + c;
                c   = (sum >> UNIT_WIDTH) & 1'b1;
                rf  = rf | (((sum & ((1 << UNIT_WIDTH) - 1)) << bit_idx));
            end
        end
        ref_add_sub = rf;
    end
    endfunction

    function automatic ref_carry;
        input [LANE_WIDTH-1:0] a1, a2;
        input                  is_sub;
        input integer          elen_in;
        input                  cin;
        integer u, bit_idx;
        integer element_size;
        integer last_elem_start;
        reg [LANE_WIDTH-1:0] op2_mod;
        reg              c;
        reg [63:0]       s1, s2, sum;
    begin
        element_size     = UNIT_WIDTH * (1 << elen_in);
        last_elem_start  = LANE_WIDTH - element_size;
        op2_mod          = is_sub ? ~a2 : a2;
        c = (LANE_WIDTH == element_size) ? cin : is_sub;
        for (u = 0; u < (1 << elen_in); u = u + 1) begin
            bit_idx = last_elem_start + u * UNIT_WIDTH;
            s1  = (a1      >> bit_idx) & ((1 << UNIT_WIDTH) - 1);
            s2  = (op2_mod >> bit_idx) & ((1 << UNIT_WIDTH) - 1);
            sum = s1 + s2 + c;
            c   = (sum >> UNIT_WIDTH) & 1'b1;
        end
        ref_carry = c ^ is_sub;
    end
    endfunction

    //========================================================================
    // Reference Model for Multiply
    //========================================================================
function automatic [2*LANE_WIDTH-1:0] ref_multiply;
    input [LANE_WIDTH-1:0] a1, a2;
    input integer          elen_in;  // 0=8b, 1=16b, 2=32b, 3=64b
    input                  signed_op;
    integer elem, bit_idx;
    integer element_size, num_elements;
    reg [2*LANE_WIDTH-1:0] result_accum;
    reg signed [63:0] s_op1, s_op2;
    reg signed [127:0] s_prod;
    reg [63:0] u_op1, u_op2;
    reg [127:0] u_prod;
    integer prod_size;
    reg [63:0] mask;
begin
    // Calculate element size based on eew_log2
    // eew_log2: 0=8b, 1=16b, 2=32b, 3=64b
    element_size = 8 * (1 << elen_in);
    num_elements = LANE_WIDTH / element_size;
    result_accum = 0;
    prod_size = element_size * 2;  // Product is double width
    
    // Create mask for extracting elements
    mask = (1 << element_size) - 1;
    
    for (elem = 0; elem < num_elements; elem = elem + 1) begin
        bit_idx = elem * element_size;
        
        if (signed_op) begin
            // Extract and sign-extend operands
            s_op1 = (a1 >> bit_idx) & mask;
            s_op2 = (a2 >> bit_idx) & mask;
            
            // Sign extend based on element size
            case (elen_in)
                0: begin  // 8-bit
                    if (s_op1[7])  s_op1 = s_op1 | 64'hFFFFFFFFFFFFFF00;
                    if (s_op2[7])  s_op2 = s_op2 | 64'hFFFFFFFFFFFFFF00;
                end
                1: begin  // 16-bit
                    if (s_op1[15]) s_op1 = s_op1 | 64'hFFFFFFFFFFFF0000;
                    if (s_op2[15]) s_op2 = s_op2 | 64'hFFFFFFFFFFFF0000;
                end
                2: begin  // 32-bit
                    if (s_op1[31]) s_op1 = s_op1 | 64'hFFFFFFFF00000000;
                    if (s_op2[31]) s_op2 = s_op2 | 64'hFFFFFFFF00000000;
                end
                3: begin  // 64-bit (already correct width)
                    // No extension needed
                end
            endcase
            
            s_prod = s_op1 * s_op2;
            
            // Place product in correct position (double-width)
            case (elen_in)
                0: result_accum[elem*16 +: 16] = s_prod[15:0];   // 8�8?16
                1: result_accum[elem*32 +: 32] = s_prod[31:0];   // 16�16?32
                2: result_accum[elem*64 +: 64] = s_prod[63:0];   // 32�32?64
                3: result_accum[0 +: 128]      = s_prod[127:0];  // 64�64?128
            endcase
        end else begin
            // Unsigned: just extract and multiply
            u_op1 = (a1 >> bit_idx) & mask;
            u_op2 = (a2 >> bit_idx) & mask;
            u_prod = u_op1 * u_op2;
            
            // Place product in correct position
            case (elen_in)
                0: result_accum[elem*16 +: 16] = u_prod[15:0];
                1: result_accum[elem*32 +: 32] = u_prod[31:0];
                2: result_accum[elem*64 +: 64] = u_prod[63:0];
                3: result_accum[0 +: 128]      = u_prod[127:0];
            endcase
        end
    end
    ref_multiply = result_accum;
end
endfunction

    //========================================================================
    // Core Check Task
    //========================================================================
    task check;
        input [2:0]            test_opcode;
        input integer          elen_val;
        input [LANE_WIDTH-1:0] op1_val, op2_val;
        input                  cin;
        input                  signed_op;
        input [LANE_WIDTH-1:0] exp_out;
        input [2*LANE_WIDTH-1:0] exp_wide;
        input                  exp_carry;
        input string           test_name;
        input                  check_wide;  // 1=check wide result, 0=check normal
        
        reg [LANE_WIDTH-1:0]   got_out;
        reg [2*LANE_WIDTH-1:0] got_wide;
        reg                    got_carry;
    begin
        opcode    = test_opcode;
        eew_log2  = elen_val;
        operand1  = op1_val;
        operand2  = op2_val;
        carry_in  = cin;
        is_signed = signed_op;
        #1; // combinational settle
        got_out   = result;
        got_wide  = result_wide;
        got_carry = carry_out;

        total_tests = total_tests + 1;
        if (check_wide) begin
            // Check wide result for multiply
            if (got_wide === exp_wide) begin
                passed_tests = passed_tests + 1;
                suite_pass   = suite_pass + 1;
                $display("[PASS] %s", test_name);
            end else begin
                failed_tests = failed_tests + 1;
                suite_fail   = suite_fail + 1;
                $display("[FAIL] %s", test_name);
                $display("  Mode=%s eew=%0d signed=%b",
                    (test_opcode==0)?"ADD":(test_opcode==1)?"SUB":
                    (test_opcode==2)?"OR" :(test_opcode==3)?"AND":
                    (test_opcode==4)?"NOT":(test_opcode==5)?"XOR":"MUL",
                    elen_val, signed_op);
                $display("  op1      : 0x%016h", op1_val);
                $display("  op2      : 0x%016h", op2_val);
                $display("  Expected : 0x%032h", exp_wide);
                $display("  Got      : 0x%032h", got_wide);
            end
        end else begin
            // Check normal result and carry
            if (got_out === exp_out &&
                (test_opcode > 3'd1 || got_carry === exp_carry)) begin
                passed_tests = passed_tests + 1;
                suite_pass   = suite_pass + 1;
                $display("[PASS] %s", test_name);
            end else begin
                failed_tests = failed_tests + 1;
                suite_fail   = suite_fail + 1;
                $display("[FAIL] %s", test_name);
                $display("  Mode=%s eew=%0d cin=%b",
                    (test_opcode==0)?"ADD":(test_opcode==1)?"SUB":
                    (test_opcode==2)?"OR" :(test_opcode==3)?"AND":
                    (test_opcode==4)?"NOT":(test_opcode==5)?"XOR":"MUL",
                    elen_val, cin);
                $display("  op1     : 0x%016h", op1_val);
                $display("  op2     : 0x%016h", op2_val);
                $display("  Expected: 0x%016h  carry=%b", exp_out, exp_carry);
                $display("  Got     : 0x%016h  carry=%b", got_out, got_carry);
            end
        end
    end
    endtask

    // Shorthand for arithmetic ops
    task check_arith;
        input [2:0]            test_opcode;
        input integer          elen_val;
        input [LANE_WIDTH-1:0] a1, a2;
        input                  cin;
        input string           name;
        reg [LANE_WIDTH-1:0]   exp;
        reg                    expc;
    begin
        exp  = ref_add_sub(a1, a2, (test_opcode==1), elen_val, cin);
        expc = ref_carry  (a1, a2, (test_opcode==1), elen_val, cin);
        check(test_opcode, elen_val, a1, a2, cin, 0, exp, 0, expc, name, 0);
    end
    endtask

    // Shorthand for logical ops
    task check_logic;
        input [2:0]            test_opcode;
        input [LANE_WIDTH-1:0] a1, a2;
        input string           name;
        reg [LANE_WIDTH-1:0]   exp;
    begin
        case (test_opcode)
            3'd2: exp = a1 | a2;
            3'd3: exp = a1 & a2;
            3'd4: exp = ~a1;
            3'd5: exp = a1 ^ a2;
            default: exp = 0;
        endcase
        check(test_opcode, 0, a1, a2, 0, 0, exp, 0, 0, name, 0);
    end
    endtask

    // Shorthand for multiply ops
    task check_multiply;
        input integer          elen_val;  // 0=8b, 1=16b, 2=32b, 3=64b
        input [LANE_WIDTH-1:0] a1, a2;
        input                  signed_op;
        input string           name;
        reg [2*LANE_WIDTH-1:0] exp_wide;
    begin
        exp_wide = ref_multiply(a1, a2, elen_val, signed_op);
        check(3'd6, elen_val, a1, a2, 0, signed_op, 0, exp_wide, 0, name, 1);
    end
    endtask

    //========================================================================
    // Main Test
    //========================================================================
    integer i, el;
    reg [LANE_WIDTH-1:0] ra, rb;

    initial begin
        $display("================================================================================");
        $display("  laneALU Testbench with Booth-Wallace Multiplier");
        $display("  LANE_WIDTH=%0d UNIT_WIDTH=%0d MAX_EEW_LOG2=%0d", 
                 LANE_WIDTH, UNIT_WIDTH, MAX_EEW_LOG2);
        $display("================================================================================");

        opcode = 0; eew_log2 = 0; operand1 = 0; operand2 = 0; 
        carry_in = 0; is_signed = 0;
        #10;

        //====================================================================
        suite_start("SUITE 1: ADD ? carry_in=0");
        //====================================================================
        for (el = 0; el <= MAX_EEW_LOG2; el = el + 1) begin
            check_arith(0, el, 64'h123456789ABCDEF0, 64'h0FEDCBA987654321, 0,
                $sformatf("ADD cin=0 eew=%0d: basic test", el));
            check_arith(0, el, 64'hFFFFFFFFFFFFFFFF, 64'h0000000000000001, 0,
                $sformatf("ADD cin=0 eew=%0d: overflow", el));
        end
        suite_end();

        //====================================================================
        suite_start("SUITE 2: SUB ? carry_in=1");
        //====================================================================
        for (el = 0; el <= MAX_EEW_LOG2; el = el + 1) begin
            check_arith(1, el, 64'h0FEDCBA987654321, 64'h123456789ABCDEF0, 1,
                $sformatf("SUB cin=1 eew=%0d: basic test", el));
        end
        suite_end();

        //====================================================================
        suite_start("SUITE 3: Logical Operations");
        //====================================================================
        check_logic(3'd2, 64'h0F0F0F0F0F0F0F0F, 64'hF0F0F0F0F0F0F0F0, "OR test");
        check_logic(3'd3, 64'h0F0F0F0F0F0F0F0F, 64'hF0F0F0F0F0F0F0F0, "AND test");
        check_logic(3'd4, 64'h123456789ABCDEF0, 64'h0000000000000000, "NOT test");
        check_logic(3'd5, 64'h0F0F0F0F0F0F0F0F, 64'hF0F0F0F0F0F0F0F0, "XOR test");
        suite_end();

        //====================================================================
        suite_start("SUITE 4: Multiply ? Signed 8-bit (eew=0)");
        //====================================================================
        // 8-bit signed multiply: each byte multiplied independently
        check_multiply(0, 64'h0F0E0D0C0B0A0908, 64'h0102030405060708, 1,
            "MUL signed eew=0: 8 independent 8�8?16 multiplies");
        
        // Simple cases
        check_multiply(0, 64'h0200000000000000, 64'h0300000000000000, 1,
            "MUL signed eew=0: 2�3=6 (single element)");
        check_multiply(0, 64'hFF00000000000000, 64'h0100000000000000, 1,
            "MUL signed eew=0: (-1)�1=-1 (sign extension)");
        check_multiply(0, 64'h7F00000000000000, 64'h7F00000000000000, 1,
            "MUL signed eew=0: 127�127 (max positive)");
        
        // All lanes active
        check_multiply(0, 64'h0102030405060708, 64'h0807060504030201, 1,
            "MUL signed eew=0: all 8 bytes");
        suite_end();

        //====================================================================
        suite_start("SUITE 5: Multiply ? Unsigned 8-bit (eew=0)");
        //====================================================================
        check_multiply(0, 64'hFF00000000000000, 64'hFF00000000000000, 0,
            "MUL unsigned eew=0: 255�255=65025");
        check_multiply(0, 64'h0102030405060708, 64'h0807060504030201, 0,
            "MUL unsigned eew=0: all 8 bytes");
        suite_end();

        //====================================================================
        suite_start("SUITE 6: Multiply ? Signed 16-bit (eew=1)");
        //====================================================================
        check_multiply(1, 64'h0100020003000400, 64'h0200030004000500, 1,
            "MUL signed eew=1: 4 independent 16�16?32 multiplies");
        check_multiply(1, 64'hFFFF000000000000, 64'h0001000000000000, 1,
            "MUL signed eew=1: (-1)�1=-1");
        check_multiply(1, 64'h7FFF000000000000, 64'h7FFF000000000000, 1,
            "MUL signed eew=1: 32767�32767");
        suite_end();

        //====================================================================
        suite_start("SUITE 7: Multiply ? Unsigned 16-bit (eew=1)");
        //====================================================================
        check_multiply(1, 64'hFFFF000000000000, 64'hFFFF000000000000, 0,
            "MUL unsigned eew=1: 65535�65535");
        check_multiply(1, 64'h0100020003000400, 64'h0500040003000200, 0,
            "MUL unsigned eew=1: all 4 halfwords");
        suite_end();

        //====================================================================
        suite_start("SUITE 8: Multiply ? Signed 32-bit (eew=2)");
        //====================================================================
        check_multiply(2, 64'h0000000100000002, 64'h0000000300000004, 1,
            "MUL signed eew=2: 2 independent 32�32?64 multiplies");
        check_multiply(2, 64'hFFFFFFFF00000000, 64'h0000000100000000, 1,
            "MUL signed eew=2: (-1)�1=-1");
        check_multiply(2, 64'h7FFFFFFF00000000, 64'h7FFFFFFF00000000, 1,
            "MUL signed eew=2: max positive 32-bit");
        suite_end();

        //====================================================================
        suite_start("SUITE 9: Multiply ? Unsigned 32-bit (eew=2)");
        //====================================================================
        check_multiply(2, 64'hFFFFFFFF00000000, 64'hFFFFFFFF00000000, 0,
            "MUL unsigned eew=2: max 32-bit");
        check_multiply(2, 64'h1234567800000000, 64'h8765432100000000, 0,
            "MUL unsigned eew=2: typical values");
        suite_end();

        //====================================================================
        suite_start("SUITE 10: Multiply ? Signed 64-bit (eew=3)");
        //====================================================================
        check_multiply(3, 64'h0000000000000002, 64'h0000000000000003, 1,
            "MUL signed eew=3: 2�3=6 (64-bit)");
        check_multiply(3, 64'hFFFFFFFFFFFFFFFF, 64'h0000000000000001, 1,
            "MUL signed eew=3: (-1)�1=-1");
        check_multiply(3, 64'h7FFFFFFFFFFFFFFF, 64'h0000000000000002, 1,
            "MUL signed eew=3: max positive � 2");
        suite_end();

        //====================================================================
        suite_start("SUITE 11: Multiply ? Unsigned 64-bit (eew=3)");
        //====================================================================
        check_multiply(3, 64'hFFFFFFFFFFFFFFFF, 64'h0000000000000002, 0,
            "MUL unsigned eew=3: max � 2");
        check_multiply(3, 64'h123456789ABCDEF0, 64'h0FEDCBA987654321, 0,
            "MUL unsigned eew=3: large values");
        suite_end();

        //====================================================================
        suite_start("SUITE 12: Multiply ? Edge Cases");
        //====================================================================
        // Zero multiplication
        check_multiply(0, 64'h0000000000000000, 64'hFFFFFFFFFFFFFFFF, 1,
            "MUL signed eew=0: 0 � anything = 0");
        check_multiply(3, 64'h0000000000000000, 64'hFFFFFFFFFFFFFFFF, 0,
            "MUL unsigned eew=3: 0 � anything = 0");
        
        // Identity
        check_multiply(0, 64'h0102030405060708, 64'h0101010101010101, 1,
            "MUL signed eew=0: multiply by 1");
        check_multiply(3, 64'h123456789ABCDEF0, 64'h0000000000000001, 0,
            "MUL unsigned eew=3: multiply by 1");
        
        // Negative � negative = positive
        check_multiply(0, 64'hFF00000000000000, 64'hFF00000000000000, 1,
            "MUL signed eew=0: (-1)�(-1)=1");
        check_multiply(1, 64'hFFFF000000000000, 64'hFFFF000000000000, 1,
            "MUL signed eew=1: (-1)�(-1)=1");
        suite_end();

        //====================================================================
        suite_start("SUITE 13: Random Tests ? All Operations");
        //====================================================================
        for (i = 0; i < NUM_RANDOM_TESTS; i = i + 1) begin
            ra = {$random, $random};
            rb = {$random, $random};
            
            for (el = 0; el <= MAX_EEW_LOG2; el = el + 1) begin
                // Arithmetic
                check_arith(0, el, ra, rb, 0,
                    $sformatf("Random ADD eew=%0d #%0d", el, i));
                check_arith(1, el, ra, rb, 1,
                    $sformatf("Random SUB eew=%0d #%0d", el, i));
                
                // Multiply signed
                check_multiply(el, ra, rb, 1,
                    $sformatf("Random MUL signed eew=%0d #%0d", el, i));
                
                // Multiply unsigned
                check_multiply(el, ra, rb, 0,
                    $sformatf("Random MUL unsigned eew=%0d #%0d", el, i));
            end
            
            // Logical (eew doesn't matter for these)
            check_logic(3'd2, ra, rb, $sformatf("Random OR #%0d", i));
            check_logic(3'd3, ra, rb, $sformatf("Random AND #%0d", i));
            check_logic(3'd4, ra, rb, $sformatf("Random NOT #%0d", i));
            check_logic(3'd5, ra, rb, $sformatf("Random XOR #%0d", i));
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
        $dumpfile("laneALU_tb.vcd");
        $dumpvars(0, laneALU_tb);
    end

endmodule