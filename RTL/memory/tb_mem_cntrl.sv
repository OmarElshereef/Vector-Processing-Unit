`timescale 1ns / 1ps

import RISCV_PKG::*;

module tb_mem_cntrl;

    // Clock generation
    reg clk;
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period = 100MHz
    end

    // Testbench signals
    reg start;
    reg stride_dir;
    reg [2:0] stride;
    reg [BYTE-1:0] vlb;
    reg [BYTE-1:0] address;
    reg mode;
    reg [2:0] SEW;
    reg [OFFSET_W-1:0] offset;
    
    wire [MLENB-1:0][BYTE-1:0] data_mem;
    wire [MLENB-1:0] valid_out_mem;
    wire [BYTE-1:0] address_out;
    
    wire [MLENB-1:0][BYTE-1:0] data_vrf;
    wire [MLENB-1:0] valid_out_vrf;
    wire running;
    wire result_ready;

    // Memory and VRF models
    reg [MLENB-1:0][BYTE-1:0] mem_model;
    reg [MLENB-1:0][BYTE-1:0] vrf_model;
    reg mem_drive_enable;
    reg vrf_drive_enable;

    // Tristate bus control
    assign data_mem = mem_drive_enable ? mem_model : {MLENB{8'bz}};
    assign data_vrf = vrf_drive_enable ? vrf_model : {MLENB{8'bz}};

    // DUT instantiation
    mem_cntrl dut (
        .clk(clk),
        .start(start),
        .stride_dir(stride_dir),
        .stride(stride),
        .vlb(vlb),
        .address(address),
        .mode(mode),
        .SEW(SEW),
        .offset(offset),
        .data_mem(data_mem),
        .valid_out_mem(valid_out_mem),
        .address_out(address_out),
        .data_vrf(data_vrf),
        .valid_out_vrf(valid_out_vrf),
        .running(running),
        .result_ready(result_ready)
    );

    // Test variables
    integer test_num;
    integer i;

    // Initialize signals
    initial begin
        // Initialize inputs
        start = 0;
        stride_dir = 0;
        stride = 0;
        vlb = 0;
        address = 0;
        mode = 0;
        SEW = 0;
        offset = 0;
        mem_drive_enable = 0;
        vrf_drive_enable = 0;
        mem_model = '{default: 8'h00};
        vrf_model = '{default: 8'h00};
        test_num = 0;

        // Wait for initial settling
        #20;

        $display("================================================");
        $display("Starting Memory Controller Testbench");
        $display("MLENB = %0d bytes", MLENB);
        $display("================================================\n");
        @(posedge clk);
        // Test 1: Load operation - Contiguous access (stride == SEW)
        test_num = 1;
        $display("[TEST %0d] Load - Contiguous Access", test_num);
        $display("Time: %0t", $time);
        
        // Setup memory with test pattern
        for (i = 0; i < MLENB; i++) begin
            mem_model[i] = i[7:0];  // Pattern: 0, 1, 2, 3, ...
        end
        
        // Configure for load operation
        mode = 1;           // Load mode
        SEW = 1;            // 8-byte elements (2^3)
        stride = 2;         // Contiguous (stride == SEW)
        stride_dir = 0;     // Forward
        offset = 0;         // No offset
        address = 8'h00;    // Start address
        vlb = MLENB;        // Full vector length
        mem_drive_enable = 1;  // Memory drives for load
        vrf_drive_enable = 0;  // VRF shouldn't drive during load
        
        // @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        
        // Wait for operation to complete
        wait(running == 1);
        $display("  Operation started at time %0t", $time);
        wait(result_ready == 1);
        $display("  Operation completed at time %0t", $time);
        
        // Check results
        //#10;
        $display("  VRF Valid Out: %h", valid_out_vrf);
        $display("  VRF Data (first 8 bytes): %h %h %h %h %h %h %h %h", 
                 data_vrf[0], data_vrf[1], data_vrf[2], data_vrf[3],
                 data_vrf[4], data_vrf[5], data_vrf[6], data_vrf[7]);
        $display("");
        
        //#50;
        wait(result_ready == 0);

        // Test 2: Store operation - Contiguous access
        test_num = 2;
        $display("[TEST %0d] Store - Contiguous Access", test_num);
        $display("Time: %0t", $time);
        
        // Setup VRF with test pattern
        for (i = 0; i < MLENB; i++) begin
            vrf_model[i] = 8'hAA - i[7:0];  // Pattern: AA, A9, A8, ...
        end
        
        // Configure for store operation
        mode = 0;           // Store mode
        SEW = 3;            // 8-byte elements
        stride = 3;         // Contiguous
        stride_dir = 0;     // Forward
        offset = 0;
        address = 8'h10;
        vlb = MLENB;
        mem_drive_enable = 0;  // Memory shouldn't drive during store
        vrf_drive_enable = 1;  // VRF drives data to store
        
        // @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        
        wait(running == 1);
        $display("  Operation started at time %0t", $time);
        wait(result_ready == 1);
        $display("  Operation completed at time %0t", $time);
        
        //#10;
        $display("  Memory Valid Out: %h", valid_out_mem);
        $display("  Memory Data (first 8 bytes): %h %h %h %h %h %h %h %h",
                 data_mem[0], data_mem[1], data_mem[2], data_mem[3],
                 data_mem[4], data_mem[5], data_mem[6], data_mem[7]);
        $display("");
        
        //#50;
        wait(result_ready == 0);

        // Test 3: Load with stride
        test_num = 3;
        $display("[TEST %0d] Load - Strided Access (2-byte elements, 1-byte stride)", test_num);
        $display("Time: %0t", $time);
        
        for (i = 0; i < MLENB; i++) begin
            mem_model[i] = 8'h10 + i[7:0];
        end
        
        mode = 1;           // Load mode
        SEW = 1;            // 2-byte elements (2^1)
        stride = 0;         // 1-byte stride (2^0)
        stride_dir = 0;     // Forward
        offset = 0;
        address = 8'h20;
        vlb = 32;           // Process 32 bytes
        mem_drive_enable = 1;
        vrf_drive_enable = 0;
        
        // @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        
        wait(running == 1);
        $display("  Operation started at time %0t", $time);
        wait(result_ready == 1);
        $display("  Operation completed at time %0t", $time);
        
        //#10;
        $display("  Address Out: %h", address_out);
        $display("");
        
        //#50;
        wait(result_ready == 0);
        // Test 4: Store with backward stride
        test_num = 4;
        $display("[TEST %0d] Store - Backward Strided Access", test_num);
        $display("Time: %0t", $time);
        
        for (i = 0; i < MLENB; i++) begin
            vrf_model[i] = 8'hF0 - i[7:0];
        end
        
        mode = 0;           // Store mode
        SEW = 2;            // 4-byte elements (2^2)
        stride = 1;         // 2-byte stride (2^1)
        stride_dir = 1;     // Backward
        offset = 0;
        address = 8'h80;
        vlb = MLENB;
        mem_drive_enable = 0;
        vrf_drive_enable = 1;
        
        // @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        
        wait(running == 1);
        $display("  Operation started at time %0t", $time);
        wait(result_ready == 1);
        $display("  Operation completed at time %0t", $time);
        
        //#10;
        $display("  Address Out: %h", address_out);
        $display("");
        
        //#50;
        wait(result_ready == 0);

        // Test 5: Load with offset
        test_num = 5;
        $display("[TEST %0d] Load - With Offset", test_num);
        $display("Time: %0t", $time);
        
        for (i = 0; i < MLENB; i++) begin
            mem_model[i] = 8'h55;
        end
        
        mode = 1;           // Load mode
        SEW = 2;            // 4-byte elements
        stride = 2;         // Contiguous 4-byte
        stride_dir = 0;     // Forward
        offset = 2;         // 2-byte offset
        address = 8'h00;
        vlb = MLENB - 2;
        mem_drive_enable = 1;
        vrf_drive_enable = 0;
        
        // @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        
        wait(running == 1);
        $display("  Operation started at time %0t", $time);
        wait(result_ready == 1);
        $display("  Operation completed at time %0t", $time);
        
        //#10;
        $display("  VRF Valid Out: %h", valid_out_vrf);
        $display("");
        
        //#50;
        wait(result_ready == 0);

        // Test 6: Small vector length
        test_num = 6;
        $display("[TEST %0d] Load - Small Vector Length", test_num);
        $display("Time: %0t", $time);
        
        for (i = 0; i < MLENB; i++) begin
            mem_model[i] = i[7:0] + 8'h80;
        end
        
        mode = 1;           // Load mode
        SEW = 0;            // 1-byte elements (2^0)
        stride = 0;         // Contiguous 1-byte
        stride_dir = 0;     // Forward
        offset = 0;
        address = 8'h00;
        vlb = 16;           // Only 16 bytes
        mem_drive_enable = 1;
        vrf_drive_enable = 0;
        
        // @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        
        wait(running == 1);
        $display("  Operation started at time %0t", $time);
        wait(result_ready == 1);
        $display("  Operation completed at time %0t", $time);
        
        //#10;
        $display("  First 16 bytes valid: %b", valid_out_vrf[15:0]);
        $display("");
        
        //#100;
        wait(result_ready == 0);

        $display("================================================");
        $display("All tests completed!");
        $display("================================================");
        
        $finish;
    end

    // Monitor for debugging
    initial begin
        $monitor("Time=%0t | running=%b | result_ready=%b | mode=%b | address_out=%h | start=%b", 
                 $time, running, result_ready, mode, address_out, start);
    end

    // Timeout watchdog
    initial begin
        #50000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
