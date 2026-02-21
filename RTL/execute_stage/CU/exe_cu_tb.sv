`timescale 1ns/1ps

module executeControlUnit_tb;

    //========================================================================
    // DUT Parameters
    //========================================================================
    localparam ADDR_WIDTH = 5;

    //========================================================================
    // DUT Signals
    //========================================================================
    reg                   clk;
    reg                   rst;
    reg                   instr_valid;
    reg  [ADDR_WIDTH-1:0] rs1;
    reg  [ADDR_WIDTH-1:0] rs2;
    wire [ADDR_WIDTH-1:0] read_addr;
    wire                  read_en;
    wire                  latch_en;
    wire                  execute;

    //========================================================================
    // DUT Instantiation
    //========================================================================
    executeControlUnit #(
        .ADDR_WIDTH (ADDR_WIDTH)
    ) dut (
        .clk         (clk),
        .rst         (rst),
        .instr_valid (instr_valid),
        .rs1         (rs1),
        .rs2         (rs2),
        .read_addr   (read_addr),
        .read_en     (read_en),
        .latch_en    (latch_en),
        .execute     (execute)
    );

    //========================================================================
    // Clock
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
    // Check Task ? samples outputs and compares
    //========================================================================
    task check;
        input                  exp_read_en;
        input                  exp_latch_en;
        input                  exp_execute;
        input [ADDR_WIDTH-1:0] exp_read_addr;
        input string           test_name;
    begin
        #1; // sample after clock edge settles
        total_tests = total_tests + 1;
        if (read_en   === exp_read_en   &&
            latch_en  === exp_latch_en  &&
            execute   === exp_execute   &&
            read_addr === exp_read_addr) begin
            passed_tests = passed_tests + 1;
            $display("[PASS] %s", test_name);
        end else begin
            failed_tests = failed_tests + 1;
            $display("[FAIL] %s", test_name);
            if (read_en   !== exp_read_en)
                $display("  read_en  : expected=%0b got=%0b", exp_read_en,   read_en);
            if (latch_en  !== exp_latch_en)
                $display("  latch_en : expected=%0b got=%0b", exp_latch_en,  latch_en);
            if (execute   !== exp_execute)
                $display("  execute  : expected=%0b got=%0b", exp_execute,   execute);
            if (read_addr !== exp_read_addr)
                $display("  read_addr: expected=%0d got=%0d", exp_read_addr, read_addr);
        end
    end
    endtask

    //========================================================================
    // Issue instruction and step through both fetch cycles
    //========================================================================
    task issue_instr;
        input [ADDR_WIDTH-1:0] src1;
        input [ADDR_WIDTH-1:0] src2;
        input string           test_name;
    begin
        // Present instruction
        @(posedge clk);
        rs1         = src1;
        rs2         = src2;
        instr_valid = 1;

        // Cycle 1 ? FETCH_A: expect read_en=1, latch_en=1, execute=0, read_addr=rs1
        @(posedge clk);
        instr_valid = 0; // deassert after one cycle
        check(1, 1, 0, src1, $sformatf("%s: FETCH_A read_addr=rs1(%0d) latch_en=1", test_name, src1));

        // Cycle 2 ? FETCH_B: expect read_en=1, latch_en=0, execute=1, read_addr=rs2
        @(posedge clk);
        check(1, 0, 1, src2, $sformatf("%s: FETCH_B read_addr=rs2(%0d) execute=1", test_name, src2));

        // Cycle 3 ? back to IDLE: all outputs should be low
        @(posedge clk);
        check(0, 0, 0, src2, $sformatf("%s: IDLE all outputs low", test_name));
    end
    endtask

    //========================================================================
    // Main
    //========================================================================
    initial begin
        $display("================================================================================");
        $display("  controlUnit Testbench");
        $display("================================================================================");

        // Init
        rst         = 1;
        instr_valid = 0;
        rs1         = 0;
        rs2         = 0;

        repeat(4) @(posedge clk);
        rst = 0;
        #1;

        //--------------------------------------------------------------------
        $display("\n--------------------------------------------------------------------------------");
        $display("SUITE 1: Reset Behavior");
        $display("--------------------------------------------------------------------------------");

        // During reset all outputs must be low
        rst = 1;
        @(posedge clk);
        check(0, 0, 0, 0, "Reset: all outputs low");
        rst = 0;
        @(posedge clk);

        //--------------------------------------------------------------------
        $display("\n--------------------------------------------------------------------------------");
        $display("SUITE 2: Basic Instruction Sequencing");
        $display("--------------------------------------------------------------------------------");

        issue_instr(5'd1,  5'd2,  "Basic instr rs1=1  rs2=2");
        issue_instr(5'd0,  5'd31, "Basic instr rs1=0  rs2=31");
        issue_instr(5'd15, 5'd16, "Basic instr rs1=15 rs2=16");
        issue_instr(5'd31, 5'd0,  "Basic instr rs1=31 rs2=0");

        //--------------------------------------------------------------------
        $display("\n--------------------------------------------------------------------------------");
        $display("SUITE 3: Same Register for rs1 and rs2");
        $display("--------------------------------------------------------------------------------");

        issue_instr(5'd5,  5'd5,  "Same reg: rs1=rs2=5");
        issue_instr(5'd0,  5'd0,  "Same reg: rs1=rs2=0");
        issue_instr(5'd31, 5'd31, "Same reg: rs1=rs2=31");

        //--------------------------------------------------------------------
        $display("\n--------------------------------------------------------------------------------");
        $display("SUITE 4: instr_valid held low ? no activity");
        $display("--------------------------------------------------------------------------------");

        rs1         = 5'd10;
        rs2         = 5'd20;
        instr_valid = 0;
repeat(4) @(posedge clk);
#1;
total_tests = total_tests + 1;
if (read_en === 0 && latch_en === 0 && execute === 0) begin
    passed_tests = passed_tests + 1;
    $display("[PASS] instr_valid=0: no read_en, no latch_en, no execute");
end else begin
    failed_tests = failed_tests + 1;
    $display("[FAIL] instr_valid=0: no read_en, no latch_en, no execute");
    $display("  read_en=%0b latch_en=%0b execute=%0b", read_en, latch_en, execute);
end

        //--------------------------------------------------------------------
        $display("\n--------------------------------------------------------------------------------");
        $display("SUITE 5: rs2 Captured Correctly When Inputs Change");
        $display("--------------------------------------------------------------------------------");

        // Issue instruction then change rs1/rs2 before FETCH_B to verify rs2 was saved
        @(posedge clk);
        rs1         = 5'd7;
        rs2         = 5'd9;
        instr_valid = 1;

        @(posedge clk);
        instr_valid = 0;
        rs1         = 5'd30; // change inputs ? should not affect saved rs2
        rs2         = 5'd30;
        check(1, 1, 0, 5'd7, "rs2 save: FETCH_A still reads rs1=7");

        @(posedge clk);
        check(1, 0, 1, 5'd9, "rs2 save: FETCH_B reads saved rs2=9 not 30");

        @(posedge clk);
        check(0, 0, 0, 5'd9, "rs2 save: back to IDLE");

        //--------------------------------------------------------------------
        $display("\n--------------------------------------------------------------------------------");
        $display("SUITE 6: Back-to-Back Instructions");
        $display("--------------------------------------------------------------------------------");

        // Issue second instruction immediately after first completes
        @(posedge clk);
        rs1         = 5'd3;
        rs2         = 5'd4;
        instr_valid = 1;

        @(posedge clk);
        instr_valid = 0;
        check(1, 1, 0, 5'd3, "B2B instr1: FETCH_A rs1=3");

        @(posedge clk);
        check(1, 0, 1, 5'd4, "B2B instr1: FETCH_B rs2=4");

        // Second instruction arrives immediately as first finishes
        @(posedge clk);
        rs1         = 5'd11;
        rs2         = 5'd12;
        instr_valid = 1;
        check(0, 0, 0, 5'd4, "B2B: IDLE between instructions");

        @(posedge clk);
        instr_valid = 0;
        check(1, 1, 0, 5'd11, "B2B instr2: FETCH_A rs1=11");

        @(posedge clk);
        check(1, 0, 1, 5'd12, "B2B instr2: FETCH_B rs2=12");

        @(posedge clk);
        check(0, 0, 0, 5'd12, "B2B instr2: back to IDLE");

        //--------------------------------------------------------------------
        $display("\n--------------------------------------------------------------------------------");
        $display("SUITE 7: Random Instructions");
        $display("--------------------------------------------------------------------------------");

        begin : random_suite
            integer i;
            reg [ADDR_WIDTH-1:0] rand_rs1, rand_rs2;
            for (i = 0; i < 20; i = i + 1) begin
                rand_rs1 = $random % 32;
                rand_rs2 = $random % 32;
                issue_instr(rand_rs1, rand_rs2,
                    $sformatf("Random #%0d rs1=%0d rs2=%0d", i, rand_rs1, rand_rs2));
            end
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
        $dumpfile("exe_cu_tb.vcd");
        $dumpvars(0, executeControlUnit_tb);
    end

endmodule
```