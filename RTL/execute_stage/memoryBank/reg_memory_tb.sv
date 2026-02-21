`timescale 1ns/1ps

module regMemory_tb;

    //========================================================================
    // Test Configuration
    //========================================================================
    localparam NUM_RANDOM_TESTS = 50;

    //========================================================================
    // DUT Parameters
    //========================================================================
    localparam WIDTH      = 512;
    localparam ELEN_WIDTH = 64;
    localparam REG_COUNT  = 32;
    localparam ADDR_WIDTH = $clog2(REG_COUNT);
    localparam BANK_COUNT = WIDTH / ELEN_WIDTH;  // 8 banks

    //========================================================================
    // DUT Signals
    //========================================================================
    reg                   clk;
    reg                   rst;
    reg                   read_en;
    reg                   write_en;
    reg  [ADDR_WIDTH-1:0] read_addr;
    reg  [ADDR_WIDTH-1:0] write_addr;
    reg  [WIDTH-1:0]      write_data;
    wire [WIDTH-1:0]      out;

    //========================================================================
    // DUT Instantiation
    //========================================================================
    regMemory #(
        .WIDTH      (WIDTH),
        .ELEN_WIDTH (ELEN_WIDTH),
        .REG_COUNT  (REG_COUNT),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) dut (
        .clk        (clk),
        .rst        (rst),
        .read_en    (read_en),
        .write_en   (write_en),
        .read_addr  (read_addr),
        .write_addr (write_addr),
        .write_data (write_data),
        .out        (out)
    );

    //========================================================================
    // Clock Generation ? 10ns period
    //========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //========================================================================
    // Test Statistics
    //========================================================================
    integer total_tests  = 0;
    integer passed_tests = 0;
    integer failed_tests = 0;

    //========================================================================
    // Shadow memory ? mirrors what we write so we can verify reads
    //========================================================================
    reg [WIDTH-1:0] shadow_mem [0:REG_COUNT-1];

    //========================================================================
    // Write Task ? drives write port for one cycle
    //========================================================================
    task do_write;
        input [ADDR_WIDTH-1:0] addr;
        input [WIDTH-1:0]      data;
    begin
        @(posedge clk);
        write_addr <= addr;
        write_data <= data;
        write_en   <= 1;
        read_en    <= 0;
        @(posedge clk);
        write_en   <= 0;
        shadow_mem[addr] = data;  // keep shadow in sync
    end
    endtask

    //========================================================================
    // Read Task ? drives read port, waits for registered output, checks it
    //========================================================================
    task do_read_check;
        input [ADDR_WIDTH-1:0] addr;
        input [WIDTH-1:0]      expected;
        input string           test_name;
        reg [WIDTH-1:0]        got;
    begin
        @(posedge clk);
        read_addr <= addr;
        read_en   <= 1;
        write_en  <= 0;

        @(posedge clk);  // data registered on this edge
        read_en <= 0;

        @(posedge clk);  // sample output after registration
        #1;
        got = out;

        total_tests = total_tests + 1;
        if (got === expected) begin
            passed_tests = passed_tests + 1;
            $display("[PASS] %s", test_name);
        end else begin
            failed_tests = failed_tests + 1;
            $display("[FAIL] %s", test_name);
            $display("  Addr    : %0d", addr);
            $display("  Expected: 0x%0128h", expected);
            $display("  Got     : 0x%0128h", got);
        end
    end
    endtask

    //========================================================================
    // Read-disabled check ? verifies output does NOT update when read_en=0
    //========================================================================
    task do_read_disabled_check;
        input [ADDR_WIDTH-1:0] addr;
        input [WIDTH-1:0]      stale_expected;
        input string           test_name;
        reg [WIDTH-1:0]        got;
    begin
        @(posedge clk);
        read_addr <= addr;
        read_en   <= 0;   // disabled
        write_en  <= 0;

        @(posedge clk);
        @(posedge clk);
        #1;
        got = out;

        total_tests = total_tests + 1;
        if (got === stale_expected) begin
            passed_tests = passed_tests + 1;
            $display("[PASS] %s  (output correctly held stale)", test_name);
        end else begin
            failed_tests = failed_tests + 1;
            $display("[FAIL] %s  (output changed when read_en=0)", test_name);
            $display("  Expected stale: 0x%0128h", stale_expected);
            $display("  Got           : 0x%0128h", got);
        end
    end
    endtask

    //========================================================================
    // Per-bank integrity check
    // Writes a unique value to each bank slice of a register and reads back
    //========================================================================
    task check_bank_isolation;
        input [ADDR_WIDTH-1:0] addr;
        input string           test_name;
        integer b;
        reg [WIDTH-1:0] wdata;
        reg [WIDTH-1:0] expected;
        reg [63:0]      bank_val;
    begin
        // Build a write value where each 64-bit bank slice is unique
        wdata = 0;
        for (b = 0; b < BANK_COUNT; b = b + 1) begin
            bank_val = 64'hDEAD_0000_0000_0000 | (b << 8) | addr;
            wdata[b*ELEN_WIDTH +: ELEN_WIDTH] = bank_val;
        end

        do_write(addr, wdata);
        do_read_check(addr, wdata,
            $sformatf("%s: reg[%0d] all banks unique pattern", test_name, addr));

        // Now verify each bank slice individually
        for (b = 0; b < BANK_COUNT; b = b + 1) begin
            total_tests = total_tests + 1;
            // trigger a fresh read
            @(posedge clk); read_addr <= addr; read_en <= 1; write_en <= 0;
            @(posedge clk); read_en <= 0;
            @(posedge clk); #1;

            if (out[b*ELEN_WIDTH +: ELEN_WIDTH] === wdata[b*ELEN_WIDTH +: ELEN_WIDTH]) begin
                passed_tests = passed_tests + 1;
                $display("[PASS] %s: bank[%0d] slice correct", test_name, b);
            end else begin
                failed_tests = failed_tests + 1;
                $display("[FAIL] %s: bank[%0d] slice mismatch", test_name, b);
                $display("  Expected slice: 0x%016h", wdata[b*ELEN_WIDTH +: ELEN_WIDTH]);
                $display("  Got slice     : 0x%016h", out[b*ELEN_WIDTH +: ELEN_WIDTH]);
            end
        end
    end
    endtask

    //========================================================================
    // Write-disabled check ? write_en=0 should not modify memory
    //========================================================================
    task check_write_disabled;
        input [ADDR_WIDTH-1:0] addr;
        input [WIDTH-1:0]      original;
        input string           test_name;
    begin
        // Attempt a write with write_en=0
        @(posedge clk);
        write_addr <= addr;
        write_data <= ~original;  // opposite data
        write_en   <= 0;          // disabled
        read_en    <= 0;
        @(posedge clk);

        // Read back and expect original data unchanged
        do_read_check(addr, original,
            $sformatf("%s: write_en=0 should not modify reg[%0d]", test_name, addr));
    end
    endtask

    //========================================================================
    // Simultaneous read/write to different addresses
    //========================================================================
task check_read_write_different_addr;
    input [ADDR_WIDTH-1:0] w_addr;
    input [ADDR_WIDTH-1:0] r_addr;
    input [WIDTH-1:0]      w_data;
    input [WIDTH-1:0]      r_expected;
    input string           test_name;
    reg [WIDTH-1:0] got;
begin
    #1;
    read_addr  = r_addr;
    write_addr = w_addr;
    write_data = w_data;
    write_en   = 1;
    read_en    = 1;

    $display("DEBUG before posedge: read_addr=%0d write_addr=%0d read_en=%0d write_en=%0d",
              read_addr, write_addr, read_en, write_en);

    @(posedge clk);
    $display("DEBUG after posedge: read_addr=%0d write_addr=%0d out=0x%0128h",
              read_addr, write_addr, out);
    #1;
    write_en = 0;
    read_en  = 0;
    shadow_mem[w_addr] = w_data;

    @(posedge clk);
    @(posedge clk);
    #1;
    got = out;

    $display("DEBUG final: read_addr=%0d got=0x%0128h", read_addr, got);

    total_tests = total_tests + 1;
    if (got === r_expected) begin
        passed_tests = passed_tests + 1;
        $display("[PASS] %s", test_name);
    end else begin
        failed_tests = failed_tests + 1;
        $display("[FAIL] %s", test_name);
        $display("  Read addr  : %0d", r_addr);
        $display("  Expected   : 0x%0128h", r_expected);
        $display("  Got        : 0x%0128h", got);
    end
end
endtask

    //========================================================================
    // Main Test Sequence
    //========================================================================
    integer i, j;
    reg [WIDTH-1:0] rdata, wdata;
    reg [WIDTH-1:0] last_out;

    initial begin
        $display("================================================================================");
        $display("  regMemory Testbench");
        $display("  WIDTH=%0d  ELEN_WIDTH=%0d  REG_COUNT=%0d  BANK_COUNT=%0d",
                  WIDTH, ELEN_WIDTH, REG_COUNT, BANK_COUNT);
        $display("================================================================================");

        // Init
        rst        = 1;
        read_en    = 0;
        write_en   = 0;
        read_addr  = 0;
        write_addr = 0;
        write_data = 0;
        for (i = 0; i < REG_COUNT; i = i + 1)
            shadow_mem[i] = 0;

        repeat(4) @(posedge clk);
        rst = 0;
        #5;

        //--------------------------------------------------------------------
        $display("\n--------------------------------------------------------------------------------");
        $display("SUITE 1: Basic Write then Read");
        $display("--------------------------------------------------------------------------------");

        // Write a known pattern to every register
        for (i = 0; i < REG_COUNT; i = i + 1) begin
            wdata = 0;
            for (j = 0; j < BANK_COUNT; j = j + 1)
                wdata[j*ELEN_WIDTH +: ELEN_WIDTH] = {$random, $random};
            do_write(i, wdata);
        end

        // Read every register back and verify
        for (i = 0; i < REG_COUNT; i = i + 1) begin
            do_read_check(i, shadow_mem[i],
                $sformatf("Read back reg[%0d]", i));
        end

        //--------------------------------------------------------------------
        $display("\n--------------------------------------------------------------------------------");
        $display("SUITE 2: Write Enable Gating");
        $display("--------------------------------------------------------------------------------");

        // Write known value to reg 0
        do_write(0, 512'hAAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA);
        // Try to overwrite with write_en=0, expect original survives
        check_write_disabled(0,
            512'hAAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA,
            "Write-enable gate");

        //--------------------------------------------------------------------
        $display("\n--------------------------------------------------------------------------------");
        $display("SUITE 3: Read Enable Gating");
        $display("--------------------------------------------------------------------------------");

        // Write something to reg 5, read it to get output stable
        do_write(5, 512'hDEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF);
        do_read_check(5,
            512'hDEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF_DEADBEEF,
            "Establish stable output for read_en gate test");

        // Now with read_en=0, output should not update even if addr changes
        last_out = out;
        do_read_disabled_check(10, last_out, "Read-enable gate: addr changed but read_en=0");

        //--------------------------------------------------------------------
        $display("\n--------------------------------------------------------------------------------");
        $display("SUITE 4: Per-Bank Isolation");
        $display("--------------------------------------------------------------------------------");

        check_bank_isolation(0,  "Bank isolation");
        check_bank_isolation(15, "Bank isolation");
        check_bank_isolation(31, "Bank isolation");

        //--------------------------------------------------------------------
        $display("\n--------------------------------------------------------------------------------");
        $display("SUITE 5: Simultaneous Read+Write to Different Addresses");
        $display("--------------------------------------------------------------------------------");

        // Pre-load reg 10
        do_write(10, 512'h5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A);

        // Write to reg 20 while reading reg 10 simultaneously
        check_read_write_different_addr(
            20,
	    10,
            512'hBEEFCAFE_BEEFCAFE_BEEFCAFE_BEEFCAFE_BEEFCAFE_BEEFCAFE_BEEFCAFE_BEEFCAFE_BEEFCAFE_BEEFCAFE_BEEFCAFE_BEEFCAFE_BEEFCAFE_BEEFCAFE_BEEFCAFE_BEEFCAFE,
            512'h5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A_5A5A5A5A,
            "Simultaneous write reg[20], read reg[10]");

        // Verify reg 20 actually got written
        do_read_check(20, shadow_mem[20], "Verify reg[20] written during simultaneous op");

        //--------------------------------------------------------------------
        $display("\n--------------------------------------------------------------------------------");
        $display("SUITE 6: Overwrite and Verify");
        $display("--------------------------------------------------------------------------------");

        // Write reg 7 twice, second write should win
        do_write(7, 512'hFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF);
        do_write(7, 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000001);
        do_read_check(7, shadow_mem[7], "Overwrite: second write wins");

        //--------------------------------------------------------------------
        $display("\n--------------------------------------------------------------------------------");
        $display("SUITE 7: All-zeros and All-ones Patterns");
        $display("--------------------------------------------------------------------------------");

        do_write(1, {WIDTH{1'b0}});
        do_read_check(1, {WIDTH{1'b0}}, "All-zeros pattern");

        do_write(2, {WIDTH{1'b1}});
        do_read_check(2, {WIDTH{1'b1}}, "All-ones pattern");

        do_write(3, {BANK_COUNT{64'hAAAAAAAAAAAAAAAA}});
        do_read_check(3, {BANK_COUNT{64'hAAAAAAAAAAAAAAAA}}, "Alternating-A pattern");

        do_write(4, {BANK_COUNT{64'h5555555555555555}});
        do_read_check(4, {BANK_COUNT{64'h5555555555555555}}, "Alternating-5 pattern");

        //--------------------------------------------------------------------
        $display("\n--------------------------------------------------------------------------------");
        $display("SUITE 8: Random Write/Read (%0d tests)", NUM_RANDOM_TESTS);
        $display("--------------------------------------------------------------------------------");

        for (i = 0; i < NUM_RANDOM_TESTS; i = i + 1) begin
            // Pick a random register and random data
            write_addr = $random % REG_COUNT;
            wdata      = 0;
            for (j = 0; j < BANK_COUNT; j = j + 1)
                wdata[j*ELEN_WIDTH +: ELEN_WIDTH] = {$random, $random};

            do_write(write_addr, wdata);
            do_read_check(write_addr, shadow_mem[write_addr],
                $sformatf("Random test #%0d: reg[%0d]", i, write_addr));
        end

        //--------------------------------------------------------------------
        $display("\n--------------------------------------------------------------------------------");
        $display("SUITE 9: Sequential Register Walk");
        $display("--------------------------------------------------------------------------------");
        // Write all registers sequentially then read all back
        for (i = 0; i < REG_COUNT; i = i + 1) begin
            wdata = 0;
            for (j = 0; j < BANK_COUNT; j = j + 1)
                wdata[j*ELEN_WIDTH +: ELEN_WIDTH] = 64'hC0DE_0000_0000_0000 | (i << 8) | j;
            do_write(i, wdata);
        end
        for (i = 0; i < REG_COUNT; i = i + 1) begin
            do_read_check(i, shadow_mem[i],
                $sformatf("Sequential walk read reg[%0d]", i));
        end

        //--------------------------------------------------------------------
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
            $display("  *** SOME TESTS FAILED - review log above ***");
        $display("================================================================================\n");


        $finish;
    end

    //========================================================================
    // Waveform Dump
    //========================================================================
    initial begin
        $dumpfile("regMemory_tb.vcd");
        $dumpvars(0, regMemory_tb);
    end

endmodule