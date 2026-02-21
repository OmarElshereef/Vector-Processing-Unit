`timescale 1ns/1ps

module regFileBank_tb;

    // Parameters
    parameter WIDTH      = 64;
    parameter REG_COUNT  = 32;
    parameter ADDR_WIDTH = 5;

    // DUT signals
    reg                  clk;
    reg                  rst;
    reg  [ADDR_WIDTH-1:0] read_addr;
    reg                  read_en;
    wire [WIDTH-1:0]     read_data;
    reg  [ADDR_WIDTH-1:0] write_addr;
    reg                  write_en;
    reg  [WIDTH-1:0]     write_data;

    // DUT instantiation
    regFileBank #(
        .WIDTH      (WIDTH),
        .REG_COUNT  (REG_COUNT),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) dut (
        .clk        (clk),
        .rst        (rst),
        .read_addr  (read_addr),
        .read_en    (read_en),
        .read_data  (read_data),
        .write_addr (write_addr),
        .write_en   (write_en),
        .write_data (write_data)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Task: write a value
    task write_reg;
        input [ADDR_WIDTH-1:0] addr;
        input [WIDTH-1:0]      data;
        begin
            @(posedge clk);
            write_addr <= addr;
            write_data <= data;
            write_en   <= 1;
            @(posedge clk);
            write_en   <= 0;
        end
    endtask

    // Task: read a value and check it
    task read_and_check;
        input [ADDR_WIDTH-1:0] addr;
        input [WIDTH-1:0]      expected;
        begin
            @(posedge clk);
            read_addr <= addr;
            read_en   <= 1;
            @(posedge clk);  // data appears after this edge (registered output)
            read_en   <= 0;
            @(posedge clk);  // sample read_data now
            if (read_data === expected)
                $display("PASS | addr=%0d | expected=0x%016h | got=0x%016h", addr, expected, read_data);
            else
                $display("FAIL | addr=%0d | expected=0x%016h | got=0x%016h", addr, expected, read_data);
        end
    endtask

    initial begin
        // Init
        clk        = 0;
        rst        = 1;
        read_en    = 0;
        write_en   = 0;
        read_addr  = 0;
        write_addr = 0;
        write_data = 0;

        #20 rst = 0;

        $display("---- Write Phase ----");
        write_reg(5'd0,  64'hDEADBEEFCAFEBABE);
        write_reg(5'd1,  64'h0123456789ABCDEF);
        write_reg(5'd2,  64'hFFFFFFFFFFFFFFFF);
        write_reg(5'd3,  64'h0000000000000000);
        write_reg(5'd4,  64'hA5A5A5A5A5A5A5A5);
        write_reg(5'd31, 64'h600DBEEF600DBEEF);

        $display("---- Read & Check Phase ----");
        read_and_check(5'd0,  64'hDEADBEEFCAFEBABE);
        read_and_check(5'd1,  64'h0123456789ABCDEF);
        read_and_check(5'd2,  64'hFFFFFFFFFFFFFFFF);
        read_and_check(5'd3,  64'h0000000000000000);
        read_and_check(5'd4,  64'hA5A5A5A5A5A5A5A5);
        read_and_check(5'd31, 64'h600DBEEF600DBEEF);

        $display("---- Two-Cycle Operand Fetch Simulation ----");
        // Simulates control unit behavior: read A then read B
        // Write two operands first
        write_reg(5'd10, 64'hAAAAAAAAAAAAAAAA);
        write_reg(5'd11, 64'hBBBBBBBBBBBBBBBB);

        // Cycle 1: fetch operand A
        @(posedge clk);
        read_addr <= 5'd10;
        read_en   <= 1;
        $display("Cycle 1: fetching operand A from reg 10");

        // Cycle 2: fetch operand B
        @(posedge clk);
        read_addr <= 5'd11;
        $display("Cycle 2: fetching operand B from reg 11");

        // Cycle 3: operand A is now available on read_data
        @(posedge clk);
        $display("Operand A = 0x%016h (expect 0xAAAAAAAAAAAAAAAA)", read_data);

        // Cycle 4: operand B is now available
        @(posedge clk);
        read_en <= 0;
        $display("Operand B = 0x%016h (expect 0xBBBBBBBBBBBBBBBB)", read_data);

        $display("---- Done ----");
        #20 $finish;
    end

endmodule