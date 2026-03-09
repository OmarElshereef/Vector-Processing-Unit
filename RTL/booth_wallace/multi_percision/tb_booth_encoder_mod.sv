// =============================================================================
//  tb_booth_encoder_mod.sv
//  Testbench for booth_encoder_mod (multi-precision Radix-4 Booth encoder)
//
//  Strategy
//  --------
//  The booth_encoder_mod generates NUM_PP = (WIDTH/2)+1 partial products.
//  Each PP has non-zero bits only within its own SIMD lane window.
//  However, when PPs for one lane are naively summed together, the two's-
//  complement sign-correction bits (SE) in ppg.sv cause the partial sum to
//  overflow the lane boundary, producing a carry-out into the next lane.
//
//  In the real design this is handled by the wallace_tree_mod carry_kill
//  signal, which zeros the CSA carry-out at each SIMD lane boundary in the
//  first compression layer.  The testbench replicates this by summing each
//  lane's PP slice INDEPENDENTLY in a wider accumulator and taking only the
//  lower lane-width bits of the result (discarding the bounded overflow carry).
//
//  PPs-per-lane by vector mode (reg PPs + last_ppg):
//    8-bit  mode :  4 reg PPs/lane  (indices 4k..4k+3)   + PP[32]
//    16-bit mode :  8 reg PPs/lane  (indices 8k..8k+7)   + PP[32]
//    32-bit mode : 16 reg PPs/lane  (indices 16k..16k+15) + PP[32]
//    64-bit mode : 32 reg PPs       (all)                 + PP[32]
//
//  For the 64-bit mode there is only one lane spanning all 128 bits, so a
//  global zero-extended sum is still correct and the carry-kill is a no-op.
//
//  Vector modes
//    2'b00 – 8-bit  : 8 independent  8x8   → 16-bit lanes packed in 128-bit
//    2'b01 – 16-bit : 4 independent 16x16  → 32-bit lanes packed in 128-bit
//    2'b10 – 32-bit : 2 independent 32x32  → 64-bit lanes packed in 128-bit
//    2'b11 – 64-bit : 1              64x64  → 128-bit result
// =============================================================================
`timescale 1ns/1ps

module tb_booth_encoder_mod;

    // -------------------------------------------------------------------------
    //  Parameters
    // -------------------------------------------------------------------------
    localparam WIDTH   = 64;
    localparam NUM_PP  = (WIDTH/2) + 1;   // 33
    localparam SUMw    = 2*WIDTH + 8;     // extra bits to hold partial-sum carry

    // -------------------------------------------------------------------------
    //  DUT ports
    // -------------------------------------------------------------------------
    reg  [WIDTH-1:0]     multiplier;
    reg  [WIDTH-1:0]     multiplicand;
    reg  [1:0]           vector_mode;
    reg                  is_unsigned;
    wire [2*WIDTH-1:0]   PPs [0:NUM_PP-1];

    // -------------------------------------------------------------------------
    //  DUT instantiation
    // -------------------------------------------------------------------------
    booth_encoder_mod #(.WIDTH(WIDTH)) dut (
        .multiplier   (multiplier),
        .multiplicand (multiplicand),
        .vector_mode  (vector_mode),
        .is_unsigned  (is_unsigned),
        .PPs          (PPs)
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
    //  Global debug sum (zero-extended, used only by dump_pps and check_64b)
    //
    //  WARNING: do NOT use pp_sum to verify 8/16/32-bit lane results.
    //  Each lane's PP slice overflows its lane boundary (by design) when summed
    //  naively; the carry is killed by the real Wallace tree.  Use the per-lane
    //  accumulators inside check_8b / check_16b / check_32b instead.
    // -------------------------------------------------------------------------
    reg [SUMw-1:0] pp_sum;
    integer pp_i;

    always @(*) begin
        pp_sum = {SUMw{1'b0}};
        for (pp_i = 0; pp_i < NUM_PP; pp_i = pp_i + 1)
            pp_sum = pp_sum + {{(SUMw - 2*WIDTH){1'b0}}, PPs[pp_i]};
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

    // ── 8-bit lane check ──────────────────────────────────────────────────────
    // 8-bit mode: 4 regular PPs per lane (indices 4k..4k+3) + PP[NUM_PP-1].
    // Sum only the lane-k slice [16k+15:16k] of each PP in a 21-bit accumulator
    // (16 data + 5 overflow bits).  The lower 16 bits of the lane_sum give the
    // correct product; the upper bits hold the bounded carry that the real
    // Wallace tree kills at the lane boundary — and are discarded here.
    task check_8b(
        input [WIDTH-1:0] mplier,
        input [WIDTH-1:0] mcand,
        input             unsign,
        input string      desc
    );
        integer k, pp_idx;
        reg [20:0]        lane_sum;
        reg [15:0]        got, exp;
        reg signed [7:0]  sa, sb;
        reg        [7:0]  ua, ub;
        reg               fail;
        begin
            apply(mplier, mcand, 2'b00, unsign);
            fail = 1'b0;
            for (k = 0; k < 8; k = k + 1) begin
                lane_sum = 21'b0;
                // 4 regular PPs for this lane
                for (pp_idx = 4*k; pp_idx < 4*k+4; pp_idx = pp_idx + 1)
                    lane_sum = lane_sum + {5'b0, PPs[pp_idx][k*16 +: 16]};
                // last_ppg contribution
                lane_sum = lane_sum + {5'b0, PPs[NUM_PP-1][k*16 +: 16]};
                got = lane_sum[15:0];  // discard overflow carry
                if (unsign) begin
                    ua  = mplier[k*8 +: 8];
                    ub  = mcand [k*8 +: 8];
                    exp = ua * ub;
                end else begin
                    sa  = mplier[k*8 +: 8];
                    sb  = mcand [k*8 +: 8];
                    exp = sa * sb;
                end
                if (got !== exp) begin
                    $display("FAIL [test%0d] 8b lane%0d %s: got=%0h exp=%0h  mplier=%0h mcand=%0h",
                             test_num, k, desc, got, exp, mplier[k*8+:8], mcand[k*8+:8]);
                    fail = 1'b1;
                end
            end
            test_num = test_num + 1;
            if (fail) fail_cnt = fail_cnt + 1;
            else      pass_cnt = pass_cnt + 1;
        end
    endtask

    // ── 16-bit lane check ─────────────────────────────────────────────────────
    // 16-bit mode: 8 regular PPs per lane (indices 8k..8k+7) + PP[NUM_PP-1].
    // 38-bit accumulator: 32 data + 6 overflow bits for up to 9 PPs.
    task check_16b(
        input [WIDTH-1:0]  mplier,
        input [WIDTH-1:0]  mcand,
        input              unsign,
        input string       desc
    );
        integer k, pp_idx;
        reg [37:0]          lane_sum;
        reg [31:0]          got, exp;
        reg signed [15:0]   sa, sb;
        reg        [15:0]   ua, ub;
        reg                 fail;
        begin
            apply(mplier, mcand, 2'b01, unsign);
            fail = 1'b0;
            for (k = 0; k < 4; k = k + 1) begin
                lane_sum = 38'b0;
                // 8 regular PPs for this lane
                for (pp_idx = 8*k; pp_idx < 8*k+8; pp_idx = pp_idx + 1)
                    lane_sum = lane_sum + {6'b0, PPs[pp_idx][k*32 +: 32]};
                // last_ppg contribution
                lane_sum = lane_sum + {6'b0, PPs[NUM_PP-1][k*32 +: 32]};
                got = lane_sum[31:0];  // discard overflow carry
                if (unsign) begin
                    ua  = mplier[k*16 +: 16];
                    ub  = mcand [k*16 +: 16];
                    exp = ua * ub;
                end else begin
                    sa  = mplier[k*16 +: 16];
                    sb  = mcand [k*16 +: 16];
                    exp = sa * sb;
                end
                if (got !== exp) begin
                    $display("FAIL [test%0d] 16b lane%0d %s: got=%0h exp=%0h  mplier=%0h mcand=%0h",
                             test_num, k, desc, got, exp, mplier[k*16+:16], mcand[k*16+:16]);
                    fail = 1'b1;
                end
            end
            test_num = test_num + 1;
            if (fail) fail_cnt = fail_cnt + 1;
            else      pass_cnt = pass_cnt + 1;
        end
    endtask

    // ── 32-bit lane check ─────────────────────────────────────────────────────
    // 32-bit mode: 16 regular PPs per lane (indices 16k..16k+15) + PP[NUM_PP-1].
    // 70-bit accumulator: 64 data + 6 overflow bits for up to 17 PPs.
    task check_32b(
        input [WIDTH-1:0]  mplier,
        input [WIDTH-1:0]  mcand,
        input              unsign,
        input string       desc
    );
        integer k, pp_idx;
        reg [69:0]          lane_sum;
        reg [63:0]          got, exp;
        reg signed [31:0]   sa, sb;
        reg        [31:0]   ua, ub;
        reg                 fail;
        begin
            apply(mplier, mcand, 2'b10, unsign);
            fail = 1'b0;
            for (k = 0; k < 2; k = k + 1) begin
                lane_sum = 70'b0;
                // 16 regular PPs for this lane
                for (pp_idx = 16*k; pp_idx < 16*k+16; pp_idx = pp_idx + 1)
                    lane_sum = lane_sum + {6'b0, PPs[pp_idx][k*64 +: 64]};
                // last_ppg contribution
                lane_sum = lane_sum + {6'b0, PPs[NUM_PP-1][k*64 +: 64]};
                got = lane_sum[63:0];  // discard overflow carry
                if (unsign) begin
                    ua  = mplier[k*32 +: 32];
                    ub  = mcand [k*32 +: 32];
                    exp = ua * ub;
                end else begin
                    sa  = mplier[k*32 +: 32];
                    sb  = mcand [k*32 +: 32];
                    exp = sa * sb;
                end
                if (got !== exp) begin
                    $display("FAIL [test%0d] 32b lane%0d %s: got=%0h exp=%0h  mplier=%0h mcand=%0h",
                             test_num, k, desc, got, exp, mplier[k*32+:32], mcand[k*32+:32]);
                    fail = 1'b1;
                end
            end
            test_num = test_num + 1;
            if (fail) fail_cnt = fail_cnt + 1;
            else      pass_cnt = pass_cnt + 1;
        end
    endtask

    // ── 64-bit check ──────────────────────────────────────────────────────────
    task check_64b(
        input [WIDTH-1:0]  mplier,
        input [WIDTH-1:0]  mcand,
        input              unsign,
        input string       desc
    );
        reg [2*WIDTH-1:0]  got, exp;
        reg signed [63:0]  sa, sb;
        reg        [63:0]  ua, ub;
        begin
            apply(mplier, mcand, 2'b11, unsign);
            got = pp_sum[2*WIDTH-1:0];
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

    // ── Individual PP sanity check ────────────────────────────────────────────
    // Print the raw PPs and per-lane sums for a given input and mode.
    //
    // NOTE: the global pp_sum is NOT displayed here because in SIMD modes
    // each lane's PP slice deliberately produces a carry-out into the next
    // lane's bit range.  The real Wallace tree kills those carries at lane
    // boundaries (carry_kill).  Summing all PPs globally therefore yields a
    // corrupted value for 8/16/32-bit modes; only the per-lane slice sum
    // (lower lane_width bits) is meaningful.
    task dump_pps(
        input [WIDTH-1:0] mplier,
        input [WIDTH-1:0] mcand,
        input [1:0]       mode,
        input             unsign
    );
        integer n, lane, pp_idx;
        // Accumulators wide enough to hold the bounded overflow carry
        reg [20:0]  lane_sum_8;
        reg [37:0]  lane_sum_16;
        reg [69:0]  lane_sum_32;
        integer     num_lanes, pps_per_lane, lane_bits;
        begin
            apply(mplier, mcand, mode, unsign);
            $display("-- PP dump: mplier=%0h mcand=%0h mode=%0b unsigned=%0b --",
                     mplier, mcand, mode, unsign);
            for (n = 0; n < NUM_PP; n = n + 1)
                $display("  PP[%02d] = %0h", n, PPs[n]);

            $display("  -- Per-lane sums (overflow carry discarded, as in Wallace tree) --");

            case (mode)
                2'b00: begin  // 8-bit: 8 lanes × 16-bit result, 4 PPs/lane
                    for (lane = 0; lane < 8; lane = lane + 1) begin
                        lane_sum_8 = 21'b0;
                        for (pp_idx = 4*lane; pp_idx < 4*lane+4; pp_idx = pp_idx+1)
                            lane_sum_8 = lane_sum_8 + {5'b0, PPs[pp_idx][lane*16 +: 16]};
                        lane_sum_8 = lane_sum_8 + {5'b0, PPs[NUM_PP-1][lane*16 +: 16]};
                        $display("  Lane[%0d] (bits[%0d:%0d])  PP_slice_sum=%0h  lane_result[15:0]=%0h",
                                 lane, lane*16+15, lane*16,
                                 lane_sum_8, lane_sum_8[15:0]);
                    end
                end
                2'b01: begin  // 16-bit: 4 lanes × 32-bit result, 8 PPs/lane
                    for (lane = 0; lane < 4; lane = lane + 1) begin
                        lane_sum_16 = 38'b0;
                        for (pp_idx = 8*lane; pp_idx < 8*lane+8; pp_idx = pp_idx+1)
                            lane_sum_16 = lane_sum_16 + {6'b0, PPs[pp_idx][lane*32 +: 32]};
                        lane_sum_16 = lane_sum_16 + {6'b0, PPs[NUM_PP-1][lane*32 +: 32]};
                        $display("  Lane[%0d] (bits[%0d:%0d])  PP_slice_sum=%0h  lane_result[31:0]=%0h",
                                 lane, lane*32+31, lane*32,
                                 lane_sum_16, lane_sum_16[31:0]);
                    end
                end
                2'b10: begin  // 32-bit: 2 lanes × 64-bit result, 16 PPs/lane
                    for (lane = 0; lane < 2; lane = lane + 1) begin
                        lane_sum_32 = 70'b0;
                        for (pp_idx = 16*lane; pp_idx < 16*lane+16; pp_idx = pp_idx+1)
                            lane_sum_32 = lane_sum_32 + {6'b0, PPs[pp_idx][lane*64 +: 64]};
                        lane_sum_32 = lane_sum_32 + {6'b0, PPs[NUM_PP-1][lane*64 +: 64]};
                        $display("  Lane[%0d] (bits[%0d:%0d])  PP_slice_sum=%0h  lane_result[63:0]=%0h",
                                 lane, lane*64+63, lane*64,
                                 lane_sum_32, lane_sum_32[63:0]);
                    end
                end
                2'b11: begin  // 64-bit: single lane, global sum is correct
                    $display("  Lane[0] (bits[127:0])  result=%0h", pp_sum[2*WIDTH-1:0]);
                end
                default: ;
            endcase
        end
    endtask

    // -------------------------------------------------------------------------
    //  Test stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_booth_encoder_mod.vcd");
        $dumpvars(0, tb_booth_encoder_mod);

        // =====================================================================
        //  8-BIT MODE
        // =====================================================================
        // Unsigned
        check_8b(64'h0000000000000000, 64'h0000000000000000, 1, "0x0 unsigned");
        check_8b(64'h0101010101010101, 64'h0101010101010101, 1, "1x1 unsigned");
        check_8b(64'hFFFFFFFFFFFFFFFF, 64'h0101010101010101, 1, "255x1 unsigned");
        check_8b(64'hFFFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFF, 1, "255x255 unsigned");
        check_8b(64'h8080808080808080, 64'h0202020202020202, 1, "128x2 unsigned");
        check_8b(64'h0F0F0F0F0F0F0F0F, 64'hF0F0F0F0F0F0F0F0, 1, "15x240 unsigned");
        check_8b(64'h0102030405060708, 64'h0807060504030201, 1, "incr x decr unsigned");
        // Signed
        check_8b(64'hFFFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFF, 0, "-1x-1 signed");
        check_8b(64'h8080808080808080, 64'h8080808080808080, 0, "-128x-128 signed");
        check_8b(64'hFFFFFFFFFFFFFFFF, 64'h0101010101010101, 0, "-1x1 signed");
        check_8b(64'h7F7F7F7F7F7F7F7F, 64'h7F7F7F7F7F7F7F7F, 0, "127x127 signed");
        check_8b(64'h8080808080808080, 64'h7F7F7F7F7F7F7F7F, 0, "-128x127 signed");
        check_8b(64'hA5A5A5A5A5A5A5A5, 64'h3C3C3C3C3C3C3C3C, 0, "arbitrary signed 8b");
        check_8b(64'h0000000000000000, 64'hFFFFFFFFFFFFFFFF, 0, "0x(-1) signed");
        check_8b(64'h0101010101010101, 64'h8080808080808080, 0, "1x(-128) signed");

        // =====================================================================
        //  16-BIT MODE
        // =====================================================================
        // Unsigned
        check_16b(64'h0000000000000000, 64'h0000000000000000, 1, "0x0 unsigned");
        check_16b(64'h0001000100010001, 64'h0001000100010001, 1, "1x1 unsigned");
        check_16b(64'hFFFFFFFFFFFFFFFF, 64'h0001000100010001, 1, "65535x1 unsigned");
        check_16b(64'hFFFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFF, 1, "65535x65535 unsigned");
        check_16b(64'h8000800080008000, 64'h0002000200020002, 1, "32768x2 unsigned");
        check_16b(64'hDEADBEEFCAFEBABE, 64'h12345678ABCDEF01, 1, "arbitrary unsigned 16b");
        check_16b(64'h0001000200030004, 64'h0004000300020001, 1, "inc x dec unsigned");
        // Signed
        check_16b(64'hFFFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFF, 0, "-1x-1 signed");
        check_16b(64'h8000800080008000, 64'h8000800080008000, 0, "-32768x-32768 signed");
        check_16b(64'hFFFFFFFFFFFFFFFF, 64'h0001000100010001, 0, "-1x1 signed");
        check_16b(64'h7FFF7FFF7FFF7FFF, 64'h7FFF7FFF7FFF7FFF, 0, "32767x32767 signed");
        check_16b(64'hA5B6C7D8E9FA0B1C, 64'h1234567890ABCDEF, 0, "arbitrary signed 16b");
        check_16b(64'h0000800000008000, 64'h7FFF00007FFF0000, 0, "mixed signed 16b");

        // =====================================================================
        //  32-BIT MODE
        // =====================================================================
        // Unsigned
        check_32b(64'h0000000000000000, 64'h0000000000000000, 1, "0x0 unsigned");
        check_32b(64'h0000000100000001, 64'h0000000100000001, 1, "1x1 unsigned");
        check_32b(64'hFFFFFFFFFFFFFFFF, 64'h0000000100000001, 1, "max x 1 unsigned");
        check_32b(64'hFFFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFF, 1, "maxXmax unsigned");
        check_32b(64'h8000000080000000, 64'h0000000200000002, 1, "2^31 x 2 unsigned");
        check_32b(64'hDEADBEEFCAFEBABE, 64'h12345678FEDCBA98, 1, "arbitrary unsigned 32b");
        // Signed
        check_32b(64'hFFFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFF, 0, "-1x-1 signed");
        check_32b(64'h8000000080000000, 64'h8000000080000000, 0, "INT_MINxINT_MIN signed");
        check_32b(64'hFFFFFFFFFFFFFFFF, 64'h0000000100000001, 0, "-1x1 signed");
        check_32b(64'h7FFFFFFF7FFFFFFF, 64'h7FFFFFFF7FFFFFFF, 0, "INT_MAXxINT_MAX signed");
        check_32b(64'hA1B2C3D4E5F60718, 64'h9ABCDEF012345678, 0, "arbitrary signed 32b");
        check_32b(64'h0000000080000000, 64'h7FFFFFFF00000000, 0, "mixed signed 32b");

        // =====================================================================
        //  64-BIT MODE
        // =====================================================================
        // Unsigned
        check_64b(64'h0000000000000000, 64'h0000000000000000, 1, "0x0 unsigned");
        check_64b(64'h0000000000000001, 64'h0000000000000001, 1, "1x1 unsigned");
        check_64b(64'hFFFFFFFFFFFFFFFF, 64'h0000000000000001, 1, "max64 x 1 unsigned");
        check_64b(64'hFFFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFF, 1, "max64 x max64 unsigned");
        check_64b(64'h8000000000000000, 64'h0000000000000002, 1, "2^63 x 2 unsigned");
        check_64b(64'hDEADBEEFCAFEBABE, 64'h0123456789ABCDEF, 1, "arbitrary unsigned 64b");
        check_64b(64'h0000000000000002, 64'h8000000000000000, 1, "2 x 2^63 unsigned");
        // Signed
        check_64b(64'hFFFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFF, 0, "-1x-1 signed");
        check_64b(64'h8000000000000000, 64'h8000000000000000, 0, "INT64_MIN x INT64_MIN signed");
        check_64b(64'hFFFFFFFFFFFFFFFF, 64'h0000000000000001, 0, "-1x1 signed");
        check_64b(64'h7FFFFFFFFFFFFFFF, 64'h7FFFFFFFFFFFFFFF, 0, "INT64_MAX x INT64_MAX signed");
        check_64b(64'hFEDCBA9876543210, 64'h0123456789ABCDEF, 0, "arbitrary signed 64b");
        check_64b(64'h8000000000000000, 64'h7FFFFFFFFFFFFFFF, 0, "INT64_MIN x INT64_MAX signed");
        check_64b(64'h0000000000000000, 64'hFFFFFFFFFFFFFFFF, 0, "0 x -1 signed");

        // =====================================================================
        //  CORNER CASES – all modes
        // =====================================================================
        // Power-of-two multipliers  (simple shift, no encode ambiguity)
        check_64b(64'h0000000000000001, 64'h0000000000000001, 0, "1x1 signed 64b");
        check_64b(64'h0000000000000002, 64'h0000000000000001, 0, "2x1 signed");
        check_64b(64'h0000000000000004, 64'h0000000000000001, 0, "4x1 signed");
        check_8b (64'h0202020202020202, 64'h0202020202020202, 0, "2x2 signed 8b");
        check_16b(64'h0004000400040004, 64'h0003000300030003, 0, "4x3 signed 16b");
        check_32b(64'h0000000800000008, 64'h0000000500000005, 0, "8x5 signed 32b");

        // Alternating-bit patterns
        check_64b(64'hAAAAAAAAAAAAAAAA, 64'h5555555555555555, 1, "0xAA..x0x55.. unsigned");
        check_64b(64'hAAAAAAAAAAAAAAAA, 64'h5555555555555555, 0, "0xAA..x0x55.. signed");
        check_8b (64'hAAAAAAAAAAAAAAAA, 64'h5555555555555555, 1, "alt-bits unsigned 8b");
        check_16b(64'hAAAAAAAAAAAAAAAA, 64'h5555555555555555, 0, "alt-bits signed 16b");

        // =====================================================================
        //  RANDOM TESTS  (50 random 64-bit values, all modes)
        // =====================================================================
        begin : rand_tests
            integer r;
            reg [WIDTH-1:0] ra, rb;
            for (r = 0; r < 50; r = r + 1) begin
                ra = $urandom_range(32'hFFFF_FFFF, 0);
                ra = {ra, $urandom_range(32'hFFFF_FFFF, 0)};
                rb = $urandom_range(32'hFFFF_FFFF, 0);
                rb = {rb, $urandom_range(32'hFFFF_FFFF, 0)};
                check_8b (ra, rb, r[0], "random 8b");
                check_16b(ra, rb, r[0], "random 16b");
                check_32b(ra, rb, r[0], "random 32b");
                check_64b(ra, rb, r[0], "random 64b");
            end
        end

        // =====================================================================
        //  Debug dump for a known case (visual inspection convenience)
        // =====================================================================
        dump_pps(64'h000000000001FFFF, 64'h0000000000FF01FF, 2'b00, 1);
        dump_pps(64'h000000000001FFFF, 64'h0000000000FF01FF, 2'b00, 0);

        dump_pps(64'h0000000000000023, 64'h0000000000000090, 2'b00, 1);
        dump_pps(64'h0000000000000023, 64'h0000000000000090, 2'b00, 0);

        // =====================================================================
        //  Summary
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
