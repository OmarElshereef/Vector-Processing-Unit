`timescale 1ns/1ps

import RISCV_PKG::*;

module tb_DROM;

    // Signals
    logic [MLENB-1:0][BYTE-1:0] data_in;
    logic [2:0] stride;
    logic [2:0] SEW;
    logic [OFFSET_W-1:0] offset;
    logic mode;
    logic clk;
    wire [MLENB-1:0][BYTE-1:0] data_out;
    wire [MLENB-1:0] valid_out;
    // wire [MLENB-1:0][BYTE:0] valid_wire; // For debugging: valid bits from control SSN 
    // wire [NUM_LAYERS:0][MLENB-1:0] Ctrl_wire; // For debugging: control signals from SCG
    // wire [MLENB-1:0] valid_pos;

    // Instantiate DUT
    DROM dut (
        .data_in(data_in),
        .stride(stride),
        .SEW(SEW),
        .offset(offset),
        .mode(mode),
        .clk(clk),
        .data_out(data_out),
        .valid_out(valid_out)
        // .valid_wire(valid_wire),
        // .Ctrl_wire(Ctrl_wire),
        // .valid_pos(valid_pos)
        
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
        $display("----------------------------------------");
        $display("%s", test_name);
        $display("stride = %0d, SEW = %0d, offset = %0d, mode = %s",
                 stride, SEW, offset, mode ? "GATHER" : "SCATTER");
        $display("Input data (first %0d elements):", num_display);
        for (int i = 0; i < num_display; i++) begin
            $display("  data_in[%2d] = %h", i, data_in[i]);
        end
        // $display("Valid wire (first %0d elements):", num_display);
        // for (int i = 0; i < num_display; i++) begin
        //     $display("  valid_wire[%2d] = %b", i, valid_wire[i]);
        // end
        // $display("Control signals (first %0d elements):", num_display);
        // for (int i = 0; i < NUM_LAYERS+1; i++) begin
        //     $display("  Ctrl_wire[%2d] = %b", i, Ctrl_wire[i]);
        // end
        // $display("Valid positions (first %0d elements):", num_display);
        // for (int i = 0; i < num_display; i++) begin
        //     $display("  valid_pos[%2d] = %b", i, valid_pos[i]);
        // end
        $display("Output data (first %0d elements):", num_display);
        for (int i = 0; i < num_display; i++) begin
            $display("  data_out[%2d] = %h (valid = %b)", i, data_out[i], valid_out[i]);
        end
        $display("");
    endtask

    // Test sequence
    initial begin
        $display("========================================");
        $display("DROM (Dynamic Reorder Module) Testbench");
        $display("MLEN = %0d, BYTE = %0d, NUM_LAYERS = %0d", MLEN, BYTE, NUM_LAYERS);
        $display("MLENB = %0d", MLENB);
        $display("========================================\n");

        // Initialize
        data_in = '0;
        stride = '0;
        SEW = '0;
        offset = '0;
        mode = '0;
        @(posedge clk);

        // Test 1: Gather contiguous elements
        $display("Test 1: Gather contiguous elements");
        for (int i = 0; i < MLENB; i++) begin
            data_in[i] = 8'hA0 + i; // Values: A0, A1, A2, ...
        end
        stride = 3'd0;  // log2(1) = 0
        SEW = 3'd0;  // 8-bit elements
        offset = 3'd0;
        mode = 1'b1; // Gather
        display_test("Test 1: Gather contiguous (stride=1, width=1, offset=0)", 8);
        // Assert: Contiguous gather should preserve order
        for (int i = 0; i < 8; i++) begin
            assert (data_out[i] == (8'hA0 + i)) else
                $error("Test 1 FAILED: data_out[%0d] = 0x%h, expected data 0x%h", 
                       i, data_out[i], 8'hA0 + i);
        end
        $display("Test 1 PASSED");

        // Test 2: Gather every 2nd element
        $display("Test 2: Gather every 2nd element");
        for (int i = 0; i < MLENB; i++) begin
            data_in[i] = 8'hB0 + i;
        end
        stride = 3'd1;  // log2(2) = 1
        SEW = 3'd0;  // 8-bit elements
        offset = 3'd5;
        mode = 1'b1; // Gather
        display_test("Test 2: Gather stride=2 (every 2nd byte)", 64);
        // Assert: Stride=2 means data_out[i] should come from data_in[2*i]
        for (int i = 0; i < 4; i++) begin
            assert (data_out[i] == (8'hB0 + 2*i)) else
                $error("Test 2 FAILED: data_out[%0d] = 0x%h, expected data 0x%h", 
                       i, data_out[i], 8'hB0 + 2*i);
        end
        $display("Test 2 PASSED");

        // Test 3: Scatter with offset
        $display("Test 3: Scatter with offset");
        for (int i = 0; i < MLENB; i++) begin
            data_in[i] = 8'hC0 + i;
        end
        stride = 3'd2;  // log2(4) = 2
        SEW = 3'd0;  // 8-bit elements
        offset = 3'd3;
        mode = 1'b0; // Scatter
        display_test("Test 3: Scatter with offset=3, stride=4", 8);

        // Test 4: Scatter contiguous elements
        $display("Test 4: Scatter contiguous elements");
        for (int i = 0; i < MLENB; i++) begin
            data_in[i] = 8'hD0 + i;
        end
        stride = 3'd0;  // log2(1) = 0
        SEW = 3'd0;  // 8-bit elements
        offset = 3'd0;
        mode = 1'b0; // Scatter
        display_test("Test 4: Scatter contiguous (stride=1, width=1, offset=0)", 8);
        // Assert: Contiguous scatter should preserve order
        for (int i = 0; i < 8; i++) begin
            assert (data_out[i] == (8'hD0 + i)) else
                $error("Test 4 FAILED: data_out[%0d] = 0x%h, expected data 0x%h", 
                       i, data_out[i], 8'hD0 + i);
        end
        $display("Test 4 PASSED");

        @(posedge clk);
        @(posedge clk);
        
        // Final verification
        $display("========================================");
        $display("All DROM tests completed successfully!");
        $display("DROM Testbench Complete");
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
