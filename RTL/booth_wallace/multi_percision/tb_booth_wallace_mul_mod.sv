// =============================================================================
//  tb_booth_wallace_mul_mod.sv
//  Testbench for booth_wallace_mul_mod (multi-precision Booth-Wallace multiplier)
//
//  Vector modes
//    2'b00 – 8-bit  : 8 independent  8x8   → 16-bit lanes in 128-bit result
//    2'b01 – 16-bit : 4 independent 16x16  → 32-bit lanes in 128-bit result
//    2'b10 – 32-bit : 2 independent 32x32  → 64-bit lanes in 128-bit result
//    2'b11 – 64-bit : 1              64x64  → 128-bit result
// =============================================================================
`timescale 1ns/1ps

module tb_booth_wallace_mul_mod;

    // -------------------------------------------------------------------------
    //  DUT ports
    // -------------------------------------------------------------------------
    localparam WIDTH = 64;

    reg  [WIDTH-1:0]   multiplier;
    reg  [WIDTH-1:0]   multiplicand;
    reg  [1:0]         vector_mode;
    reg                is_unsigned;
    wire [2*WIDTH-1:0] result;

    // -------------------------------------------------------------------------
    //  DUT instantiation
    // -------------------------------------------------------------------------
    booth_wallace_mul_mod #(.WIDTH(WIDTH)) dut (
        .multiplier   (multiplier),
        .multiplicand (multiplicand),
        .vector_mode  (vector_mode),
        .is_unsigned  (is_unsigned),
        .result       (result)
    );

    // -------------------------------------------------------------------------
    //  Simulation bookkeeping
    // -------------------------------------------------------------------------
    integer pass_cnt, fail_cnt, test_num;
    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
        test_num = 0;
    end

    // -------------------------------------------------------------------------
    //  Helper tasks
    // -------------------------------------------------------------------------

    // Apply inputs and wait for combinational settling
    task apply(
        input [WIDTH-1:0] mplier,
        input [WIDTH-1:0] mcand,
        input [1:0]       mode,
        input             unsign
    );
        multiplier   = mplier;
        multiplicand = mcand;
        vector_mode  = mode;
        is_unsigned  = unsign;
        #10;
    endtask

    // ── 8-bit lane check ─────────────────────────────────────────────────────
    // Lane k occupies result[k*16 +: 16]
    task check_8b(
        input [WIDTH-1:0] mplier,
        input [WIDTH-1:0] mcand,
        input             unsign,
        input string       desc
    );
        integer k;
        reg [15:0] got, exp;
        reg signed [7:0]  sa, sb;
        reg        [7:0]  ua, ub;
        reg fail;
        begin
            apply(mplier, mcand, 2'b00, unsign);
            fail = 0;
            for (k = 0; k < 8; k = k+1) begin
                got = result[k*16 +: 16];
                if (unsign) begin
                    ua  = mplier [k*8 +: 8];
                    ub  = mcand  [k*8 +: 8];
                    exp = ua * ub;
                end else begin
                    sa  = mplier [k*8 +: 8];
                    sb  = mcand  [k*8 +: 8];
                    exp = sa * sb;
                end
                if (got !== exp) begin
                    $display("FAIL [test%0d] 8b lane%0d %s: got=%0h exp=%0h  mplier=%0h mcand=%0h",
                             test_num, k, desc, got, exp, mplier[k*8+:8], mcand[k*8+:8]);
                    fail = 1;
                end
            end
            test_num = test_num + 1;
            if (fail) fail_cnt = fail_cnt + 1;
            else      pass_cnt = pass_cnt + 1;
        end
    endtask

    // ── 16-bit lane check ────────────────────────────────────────────────────
    // Lane k occupies result[k*32 +: 32]
    task check_16b(
        input [WIDTH-1:0] mplier,
        input [WIDTH-1:0] mcand,
        input             unsign,
        input string       desc
    );
        integer k;
        reg [31:0] got, exp;
        reg signed [15:0] sa, sb;
        reg        [15:0] ua, ub;
        reg fail;
        begin
            apply(mplier, mcand, 2'b01, unsign);
            fail = 0;
            for (k = 0; k < 4; k = k+1) begin
                got = result[k*32 +: 32];
                if (unsign) begin
                    ua  = mplier [k*16 +: 16];
                    ub  = mcand  [k*16 +: 16];
                    exp = ua * ub;
                end else begin
                    sa  = mplier [k*16 +: 16];
                    sb  = mcand  [k*16 +: 16];
                    exp = sa * sb;
                end
                if (got !== exp) begin
                    $display("FAIL [test%0d] 16b lane%0d %s: got=%0h exp=%0h  mplier=%0h mcand=%0h",
                             test_num, k, desc, got, exp, mplier[k*16+:16], mcand[k*16+:16]);
                    fail = 1;
                end
            end
            test_num = test_num + 1;
            if (fail) fail_cnt = fail_cnt + 1;
            else      pass_cnt = pass_cnt + 1;
        end
    endtask

    // ── 32-bit lane check ────────────────────────────────────────────────────
    // Lane k occupies result[k*64 +: 64]
    task check_32b(
        input [WIDTH-1:0] mplier,
        input [WIDTH-1:0] mcand,
        input             unsign,
        input string       desc
    );
        integer k;
        reg [63:0] got, exp;
        reg signed [31:0] sa, sb;
        reg        [31:0] ua, ub;
        reg fail;
        begin
            apply(mplier, mcand, 2'b10, unsign);
            fail = 0;
            for (k = 0; k < 2; k = k+1) begin
                got = result[k*64 +: 64];
                if (unsign) begin
                    ua  = mplier [k*32 +: 32];
                    ub  = mcand  [k*32 +: 32];
                    exp = ua * ub;
                end else begin
                    sa  = mplier [k*32 +: 32];
                    sb  = mcand  [k*32 +: 32];
                    exp = sa * sb;
                end
                if (got !== exp) begin
                    $display("FAIL [test%0d] 32b lane%0d %s: got=%0h exp=%0h  mplier=%0h mcand=%0h",
                             test_num, k, desc, got, exp, mplier[k*32+:32], mcand[k*32+:32]);
                    fail = 1;
                end
            end
            test_num = test_num + 1;
            if (fail) fail_cnt = fail_cnt + 1;
            else      pass_cnt = pass_cnt + 1;
        end
    endtask

    // ── 64-bit check ─────────────────────────────────────────────────────────
    task check_64b(
        input [WIDTH-1:0]   mplier,
        input [WIDTH-1:0]   mcand,
        input               unsign,
        input string         desc
    );
        reg [2*WIDTH-1:0] got, exp;
        reg signed [63:0] sa, sb;
        reg        [63:0] ua, ub;
        begin
            apply(mplier, mcand, 2'b11, unsign);
            got = result;
            if (unsign) begin
                ua  = mplier;
                ub  = mcand;
                exp = ua * ub;
            end else begin
                sa  = mplier;
                sb  = mcand;
                exp = sa * sb;
            end
            test_num = test_num + 1;
            if (got !== exp) begin
                $display("FAIL [test%0d] 64b %s: got=%0h exp=%0h  mplier=%0h mcand=%0h",
                         test_num-1, desc, got, exp, mplier, mcand);
                fail_cnt = fail_cnt + 1;
            end else begin
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    //  Test stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_booth_wallace_mul_mod.vcd");
        $dumpvars(0, tb_booth_wallace_mul_mod);

        // =====  8-BIT MODE  ==================================================
        // -- Unsigned --
        check_8b(64'h0000000000000000, 64'h0000000000000000, 1, "0x0 unsigned");
        check_8b(64'h0101010101010101, 64'h0101010101010101, 1, "1x1 unsigned");
        check_8b(64'hFFFFFFFFFFFFFFFF, 64'h0101010101010101, 1, "255x1 unsigned");
        check_8b(64'hFFFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFF, 1, "255x255 unsigned");
        check_8b(64'h8080808080808080, 64'h0202020202020202, 1, "128x2 unsigned");
        check_8b(64'h0F0F0F0F0F0F0F0F, 64'hF0F0F0F0F0F0F0F0, 1, "15x240 unsigned");
        // -- Signed --
        check_8b(64'hFFFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFF, 0, "-1x-1 signed");
        check_8b(64'h8080808080808080, 64'h8080808080808080, 0, "-128x-128 signed");
        check_8b(64'hFFFFFFFFFFFFFFFF, 64'h0101010101010101, 0, "-1x1 signed");
        check_8b(64'h7F7F7F7F7F7F7F7F, 64'h7F7F7F7F7F7F7F7F, 0, "127x127 signed");
        check_8b(64'h8080808080808080, 64'h7F7F7F7F7F7F7F7F, 0, "-128x127 signed");
        check_8b(64'hA5A5A5A5A5A5A5A5, 64'h3C3C3C3C3C3C3C3C, 0, "arbitrary signed 8b");

        // =====  16-BIT MODE  =================================================
        // -- Unsigned --
        check_16b(64'h0000000000000000, 64'h0000000000000000, 1, "0x0 unsigned");
        check_16b(64'h0001000100010001, 64'h0001000100010001, 1, "1x1 unsigned");
        check_16b(64'hFFFFFFFFFFFFFFFF, 64'h0001000100010001, 1, "65535x1 unsigned");
        check_16b(64'hFFFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFF, 1, "65535x65535 unsigned");
        check_16b(64'h8000800080008000, 64'h0002000200020002, 1, "32768x2 unsigned");
        check_16b(64'hDEADBEEFCAFEBABE, 64'h12345678ABCDEF01, 1, "arbitrary unsigned 16b");
        // -- Signed --
        check_16b(64'hFFFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFF, 0, "-1x-1 signed");
        check_16b(64'h8000800080008000, 64'h8000800080008000, 0, "-32768x-32768 signed");
        check_16b(64'hFFFFFFFFFFFFFFFF, 64'h0001000100010001, 0, "-1x1 signed");
        check_16b(64'h7FFF7FFF7FFF7FFF, 64'h7FFF7FFF7FFF7FFF, 0, "32767x32767 signed");
        check_16b(64'hA5B6C7D8E9FA0B1C, 64'h1234567890ABCDEF, 0, "arbitrary signed 16b");

        // =====  32-BIT MODE  =================================================
        // -- Unsigned --
        check_32b(64'h0000000000000000, 64'h0000000000000000, 1, "0x0 unsigned");
        check_32b(64'h0000000100000001, 64'h0000000100000001, 1, "1x1 unsigned");
        check_32b(64'hFFFFFFFFFFFFFFFF, 64'h0000000100000001, 1, "max x 1 unsigned");
        check_32b(64'hFFFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFF, 1, "maxXmax unsigned");
        check_32b(64'h8000000080000000, 64'h0000000200000002, 1, "2147483648x2 unsigned");
        check_32b(64'hDEADBEEFCAFEBABE, 64'h12345678FEDCBA98, 1, "arbitrary unsigned 32b");
        // -- Signed --
        check_32b(64'hFFFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFF, 0, "-1x-1 signed");
        check_32b(64'h8000000080000000, 64'h8000000080000000, 0, "INT_MINxINT_MIN signed");
        check_32b(64'hFFFFFFFFFFFFFFFF, 64'h0000000100000001, 0, "-1x1 signed");
        check_32b(64'h7FFFFFFF7FFFFFFF, 64'h7FFFFFFF7FFFFFFF, 0, "INT_MAXxINT_MAX signed");
        check_32b(64'hA1B2C3D4E5F60718, 64'h9ABCDEF012345678, 0, "arbitrary signed 32b");

        // =====  64-BIT MODE  =================================================
        // -- Unsigned --
        check_64b(64'h0000000000000000, 64'h0000000000000000, 1, "0x0 unsigned");
        check_64b(64'h0000000000000001, 64'h0000000000000001, 1, "1x1 unsigned");
        check_64b(64'hFFFFFFFFFFFFFFFF, 64'h0000000000000001, 1, "max64 x 1 unsigned");
        check_64b(64'hFFFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFF, 1, "max64 x max64 unsigned");
        check_64b(64'h8000000000000000, 64'h0000000000000002, 1, "2^63 x 2 unsigned");
        check_64b(64'hDEADBEEFCAFEBABE, 64'h0123456789ABCDEF, 1, "arbitrary unsigned 64b");
        // -- Signed --
        check_64b(64'hFFFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFF, 0, "-1x-1 signed");
        check_64b(64'h8000000000000000, 64'h8000000000000000, 0, "INT64_MIN x INT64_MIN signed");
        check_64b(64'hFFFFFFFFFFFFFFFF, 64'h0000000000000001, 0, "-1x1 signed");
        check_64b(64'h7FFFFFFFFFFFFFFF, 64'h7FFFFFFFFFFFFFFF, 0, "INT64_MAX x INT64_MAX signed");
        check_64b(64'hFEDCBA9876543210, 64'h0123456789ABCDEF, 0, "arbitrary signed 64b");

        // =====  RANDOM TESTS  ================================================
        begin : rand_tests
            integer r;
            reg [WIDTH-1:0] ra, rb;
            for (r = 0; r < 50; r = r+1) begin
                ra = $urandom_range(32'hFFFF_FFFF, 0);
                ra = {ra, $urandom_range(32'hFFFF_FFFF, 0)};
                rb = $urandom_range(32'hFFFF_FFFF, 0);
                rb = {rb, $urandom_range(32'hFFFF_FFFF, 0)};
                check_8b (ra, rb, r[0],  "random");
                check_16b(ra, rb, r[0],  "random");
                check_32b(ra, rb, r[0],  "random");
                check_64b(ra, rb, r[0],  "random");
            end
        end

        // =====================================================================
        $display("==============================================");
        $display("  Tests done: %0d   PASS: %0d   FAIL: %0d",
                 test_num, pass_cnt, fail_cnt);
        $display("==============================================");
        if (fail_cnt == 0)
            $display("ALL TESTS PASSED");
        else
            $display("*** %0d TEST(S) FAILED ***", fail_cnt);

        $finish;
    end

endmodule
