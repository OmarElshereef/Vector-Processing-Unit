`timescale 1ns/1ps

import RISCV_PKG::*;

module scg_tb;

    // Testbench signals
    logic [2:0] stride;
    logic [2:0] SEW;
    logic [OFFSET_W-1:0] offset;
    logic [NUM_LAYERS:0][MLENB-1:0] controls;
    logic [BYTE-1:0] intermediate_positions [0:NUM_LAYERS][MLENB-1:0];// For debugging
    
    // Instantiate the DUT (Device Under Test)
    scg dut (
        .stride(stride),
        .SEW(SEW),
        .offset(offset),
        .controls(controls),
        .intermediate_positions(intermediate_positions)
    );
    
    // Test procedure
    initial begin
        $display("========================================");
        $display("Starting SCG (Shift Count Generation) Testbench");
        $display("MLEN = %0d, NUM_LAYERS = %0d, MLENB = %0d", MLEN, NUM_LAYERS, MLENB);
        $display("========================================\n");

        SEW = 3'd1;  // 16-bit elements
        stride = 3'd2;  // log2(4) = 2
        offset = 3;
        #10;
        display_results();


        SEW = 3'd2;  // 32-bit elements
        stride = 3'd3;  // log2(8) = 3
        offset = 1;
        #10;
        display_results();


        SEW = 3'd2;  // 32-bit elements
        stride = 3'd3;  // log2(8) = 3
        offset = 2;
        #10;
        display_results();
        
        // Test 1: Scatter mode with different stride and SEW
        SEW = 3'd2;  // 32-bit elements
        stride = 3'd3;  // log2(8) = 3
        offset = 3;
        #10;
        display_results();

        SEW = 3'd2;  // 32-bit elements
        stride = 3'd3;  // log2(8) = 3
        offset = 4;
        #10;
        display_results();


        SEW = 3'd2;  // 32-bit elements
        stride = 3'd3;  // log2(8) = 3
        offset = 5;
        #10;
        display_results();
        
        // Test 2: Gather mode with different stride and SEW
        SEW = 3'd0;  // 8-bit elements
        stride = 3'd0;  // log2(1) = 0
        offset = 3;
        #10;
        display_results();
        
        $display("\n========================================");
        $display("SCG Testbench Completed Successfully");
        $display("========================================");
        
        $finish;
    end
    
    // Task to display results
    task display_results;
        integer i, j;
        begin
            $display("  Inputs: SEW=%0d, stride=%0d, offset=%0d", 
                 SEW, stride, offset);
            $display("  Control signals (Layer x Element):");
            for (i = 0; i < NUM_LAYERS; i = i + 1) begin
                $write("    Layer[%0d]: ", i);
                $write("%b ", controls[i]);
                $display("");
            end
            $display("  Intermediate positions (Layer x Element):");
            for (i = 0; i < NUM_LAYERS+1; i = i + 1) begin
                $write("    Layer[%0d]: ", i);
                for (j = 0; j < MLENB; j = j + 1) begin
                    $write("%0d ", intermediate_positions[i][j]);
                end
                $display("");
            end
            $display("");
        end
    endtask
endmodule
