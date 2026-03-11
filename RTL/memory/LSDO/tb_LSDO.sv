`timescale 1ns/1ps

import RISCV_PKG::*;

module tb_LSDO;

    // Signals
    logic [MLENB-1:0][BYTE-1:0] data_in;
    logic clk;
    logic data_dir;
    logic [BYTE-1:0] shift;
    logic mode;
    logic [2:0] SEW;
    logic [OFFSET_W-1:0] offset;
    logic [2:0] stride;  // Stride as log2(bytes)
    wire [MLENB-1:0][BYTE-1:0] data_out;
    wire [MLENB-1:0] vout;

    // Instantiate DUT
    LSDO dut (
        .data_in(data_in),
        .clk(clk),
        .data_dir(data_dir),
        .shift(shift),
        .mode(mode),
        .SEW(SEW),
        .offset(offset),
        .stride(stride),
        .data_out(data_out),
        .valid_out(vout)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Helper task to display results
    task display_test(input string test_name, input int num_display);
        @(posedge clk);
        @(posedge clk);
        #1;
        $display("========================================");
        $display("%s", test_name);
        $display("Mode: %s, Direction: %s",
                 mode ? "LOAD" : "STORE",
                 data_dir ? "BACKWARD" : "FORWARD");
        $display("SEW: %0d, Offset: %0d, Stride: %0d",
                 SEW, offset, stride);
        $display("Shift: %0d",shift);
        $display("----------------------------------------");
        if (data_dir) begin
            // Backward: show last x elements for input
            $display("Input data (last %0d bytes):", num_display);
            for (int i = MLENB - num_display; i < MLENB; i++) begin
                $write("%02h ", data_in[i]);
                if ((i - (MLENB - num_display) + 1) % 16 == 0) $display("");
            end
            if (num_display % 16 != 0) $display("");
        end else begin
            // Forward: show first x elements for input
            $display("Input data (first %0d bytes):", num_display);
            for (int i = 0; i < num_display; i++) begin
                $write("%02h ", data_in[i]);
                if ((i + 1) % 16 == 0) $display("");
            end
            if (num_display % 16 != 0) $display("");
        end
        // Always show first x elements for output
        $display("Output data (first %0d bytes):", num_display);
        for (int i = 0; i < num_display; i++) begin
            $write("%02h ", data_out[i]);
            if ((i + 1) % 16 == 0) $display("");
        end
        if (num_display % 16 != 0) $display("");
        
        // Display valid bits
        $display("Valid bits (first %0d bytes):", num_display);
        for (int i = 0; i < num_display; i++) begin
            $write("%0d  ", vout[i]);
            if ((i + 1) % 16 == 0) $display("");
        end
        if (num_display % 16 != 0) $display("");
        $display("");
    endtask

    // Helper task to initialize data with pattern
    task init_data(input [7:0] start_val);
        for (int i = 0; i < MLENB; i++) begin
            data_in[i] = start_val + i[7:0];
        end
    endtask

    // Test sequence
    initial begin
        $display("========================================");
        $display("LSDO (Load/Store Data Ordering) Testbench");
        $display("MLEN = %0d, BYTE = %0d", MLEN, BYTE);
        $display("MLENB = %0d bytes", MLENB);
        $display("========================================\n");

        // Initialize
        data_in = '0;
        data_dir = '0;
        shift = '0;
        mode = '0;
        SEW = '0;
        offset = '0;
        stride = '0;
        @(posedge clk);

        // ============================================
        // Test 1: Load mode, contiguous, forward
        // ============================================
        $display("\n=== Test 1: Load Mode, Contiguous, Forward ===");
        init_data(8'hA0);
        mode = 1'b1;        // Load
        data_dir = 1'b0;    // Forward
        shift = 8'd0;       // No shift
        SEW = 3'd0;  // 1 byte elements (SEW = 0 means 8-bit elements)
        offset = 3'd0;      // No offset
        stride = 3'd0;      // log2(1) = 0
        display_test("Test 1: Load, Contiguous, Forward", 16);

        // ============================================
        // Test 2: Load mode, contiguous, backward
        // ============================================
        $display("\n=== Test 2: Load Mode, Contiguous, Backward ===");
        init_data(8'hB0);
        mode = 1'b1;        // Load
        data_dir = 1'b1;    // Backward
        shift = 8'd0;       // No shift
        SEW = 3'd0;  // 1 byte elements (SEW = 0 means 8-bit elements)
        offset = 3'd0;
        stride = 3'd0;      // log2(1) = 0
        display_test("Test 2: Load, Contiguous, Backward", 16);

        // ============================================
        // Test 3: Load mode, forward with shift
        // ============================================
        $display("\n=== Test 3: Load Mode, Forward with Left Shift ===");
        init_data(8'hC0);
        mode = 1'b1;        // Load
        data_dir = 1'b0;    // Forward
        shift = 8'd4;       // Shift by 4 bytes
        SEW = 3'd1;  // 2 byte elements (SEW = 1 means 16-bit elements)
        offset = 3'd2;
        stride = 3'd2;      // log2(4) = 2
        display_test("Test 3: Load, Forward, Left Shift 4", 32);

        // ============================================
        // Test 4: Load mode, backward with shift
        // ============================================
        $display("\n=== Test 4: Load Mode, Backward with Right Shift ===");
        init_data(8'hD0);
        mode = 1'b1;        // Load
        data_dir = 1'b1;    // Backward
        shift = 8'd4;       // Shift by 4 bytes
        SEW = 3'd2;  // 4 byte elements (SEW = 2 means 32-bit elements)
        offset = 3'd2;
        stride = 3'd2;      // log2(4) = 2
        display_test("Test 4: Load, Backward, Right Shift 4", 32);

        // ============================================
        // Test 5: Store mode, forward
        // ============================================
        $display("\n=== Test 5: Store Mode, Forward ===");
        init_data(8'h10);
        mode = 1'b0;        // Store
        data_dir = 1'b0;    // Forward
        shift = 8'd0;       // No shift
        SEW = 3'd0;  // 1 byte elements (SEW = 0 means 8-bit elements)
        offset = 3'd0;
        stride = 3'd0;      // log2(1) = 0
        display_test("Test 5: Store, Forward", 16);

        // ============================================
        // Test 6: Store mode, contiguous, backward
        // ============================================
        $display("\n=== Test 6: Store Mode, Contiguous, Backward ===");
        init_data(8'h20);
        mode = 1'b0;        // Store
        data_dir = 1'b1;    // Backward
        shift = 8'd0;
        SEW = 3'd0;  // 1 byte elements (SEW = 0 means 8-bit elements)
        offset = 3'd0;
        stride = 3'd0;      // log2(1) = 0
        display_test("Test 6: Store, Backward", 16);

        // ============================================
        // Test 7: Store mode, forward
        // ============================================
        $display("\n=== Test 7: Store Mode, Forward ===");
        init_data(8'h30);
        mode = 1'b0;        // Store
        data_dir = 1'b0;    // Forward
        shift = 8'd4;       // Shift by 4 bytes
        SEW = 3'd1;  // 2 byte elements (SEW = 1 means 16-bit elements)
        offset = 3'd2;
        stride = 3'd2;      // log2(4) = 2
        display_test("Test 7: Store, Forward, Left Shift 4", 32);

        // ============================================
        // Test 8: Store mode, backward
        // ============================================
        $display("\n=== Test 8: Store Mode, Backward ===");
        init_data(8'h40);
        mode = 1'b0;        // Store
        data_dir = 1'b1;    // Backward
        shift = 8'd0;       // Shift by 2 bytes
        SEW = 3'd1;  // 4 byte elements (SEW = 2 means 32-bit elements)
        offset = 3'd2;
        stride = 3'd2;      // log2(8) = 3
        display_test("Test 8: Store, Backward, Right Shift 2", 32);

        // ============================================
        // Test 9: Load with offset
        // ============================================
        $display("\n=== Test 9: Load Mode with Offset ===");
        init_data(8'h50);
        mode = 1'b1;        // Load
        data_dir = 1'b0;    // Forward
        shift = 8'd0;       // No shift
        SEW = 3'd1;  // 2 byte elements (SEW = 1 means 16-bit elements)
        offset = 3'd3;      // Offset by 3
        stride = 3'd2;      // log2(4) = 2
        display_test("Test 9: Load with Offset 3", 32);

        // ============================================
        // Test 10: Complex scenario - Load with all features
        // ============================================
        $display("\n=== Test 10: Complex Load Test ===");
        init_data(8'h60);
        mode = 1'b1;        // Load
        data_dir = 1'b1;    // Backward
        shift = 8'd2;       // Shift by 2 bytes
        SEW = 3'd2;  // 4 byte elements (SEW = 2 means 32-bit elements)
        offset = 3'd1;
        stride = 3'd2;      // log2(4) = 2
        display_test("Test 10: Load, Backward, Left Shift 2, Offset 1", 32);

        // ============================================
        // Test 11: Complex scenario - Store with all features
        // ============================================
        $display("\n=== Test 11: Complex Store Test ===");
        init_data(8'h70);
        mode = 1'b0;        // Store
        data_dir = 1'b1;    // Backward
        shift = 8'd4;       // Shift by 4 bytes
        SEW = 3'd3;  // 8 byte elements (SEW = 3 means 64-bit elements)
        offset = 3'd2;
        stride = 3'd3;      // log2(8) = 3
        display_test("Test 11: Store, Backward, Right Shift 4, Offset 2", 32);

        // ============================================
        // Test 12: Edge case - Maximum shift
        // ============================================
        $display("\n=== Test 12: Edge Case - Large Shift ===");
        init_data(8'h80);
        mode = 1'b1;        // Load
        data_dir = 1'b0;    // Forward
        shift = 8'd32;      // Large shift
        SEW = 3'd0;  // 1 byte elements (SEW = 0 means 8-bit elements)
        offset = 3'd0;
        stride = 3'd0;      // log2(1) = 0
        display_test("Test 12: Load with Large Left Shift (32)", 48);

        // ============================================
        // Test 13: Edge case - Large element width
        // ============================================
        $display("\n=== Test 13: Edge Case - Large Element Width ===");
        init_data(8'h90);
        mode = 1'b1;        // Load
        data_dir = 1'b0;    // Forward
        shift = 8'd0;       
        SEW = 3'd3;  // 8 byte elements (SEW = 3 means 64-bit elements)
        offset = 3'd0;
        stride = 3'd3;      // log2(8) = 3
        display_test("Test 13: Load with 8-byte Elements", 32);

        // End of simulation
        @(posedge clk);
        @(posedge clk);
        $display("\n========================================");
        $display("LSDO Testbench Completed");
        $display("========================================");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #10000;
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule
