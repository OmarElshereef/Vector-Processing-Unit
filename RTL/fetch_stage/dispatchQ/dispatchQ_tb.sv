`timescale 1ns/1ps

module dispatchQ_tb;

    // Parameters
    parameter INSTR_WIDTH     = 32;
    parameter SCALAR_VAL_SIZE = 32;
    parameter ID_WIDTH        = 5;
    parameter Q_DEPTH         = 8;
    parameter VTYPE_WIDTH     = 8;
    parameter VL_WIDTH        = 32;

    // Signals
    logic clk;
    logic rst_n;
    logic flush;
    logic push;
    logic [INSTR_WIDTH-1:0]    instr_in;
    logic [SCALAR_VAL_SIZE-1:0] rs1_value_in;
    logic [SCALAR_VAL_SIZE-1:0] rs2_value_in;
    logic [ID_WIDTH-1:0]       instr_id_in;
    logic [VTYPE_WIDTH-1:0]    vtype_in;
    logic [VL_WIDTH-1:0]       vl_in;
    
    logic full;
    logic pop;
    logic empty;
    logic [INSTR_WIDTH-1:0]    instr_out;
    logic [SCALAR_VAL_SIZE-1:0] rs1_value_out;
    logic [SCALAR_VAL_SIZE-1:0] rs2_value_out;
    logic [ID_WIDTH-1:0]       instr_id_out;
    logic [VTYPE_WIDTH-1:0]    vtype_out;
    logic [VL_WIDTH-1:0]       vl_out;

    // Instantiate DUT
    dispatchQ #(
        .Q_DEPTH(Q_DEPTH)
    ) dut (.*);

    // Clock Generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Helper Task to Push
    task push_entry(input [31:0] val);
        wait(!full);
        @(posedge clk);
        #1; // Drive after edge
        push         = 1'b1;
        instr_in     = val;
        rs1_value_in = val + 1;
        rs2_value_in = val + 2;
        instr_id_in  = val[4:0];
        vtype_in     = 8'hAA;
        vl_in        = 32'd16;
        @(posedge clk);
        #1 push = 1'b0;
    endtask

    // Helper Task to Pop
    task pop_entry();
        wait(!empty);
        @(posedge clk);
        #1;
        pop = 1'b1;
        @(posedge clk);
        #1 pop = 1'b0;
    endtask

    // Stimulus
    initial begin
        // Initialize
        rst_n = 0;
        flush = 0;
        push  = 0;
        pop   = 0;
        instr_in = 0;
        rs1_value_in = 0;
        rs2_value_in = 0;
        instr_id_in  = 0;
        vtype_in = 0;
        vl_in = 0;

        repeat(2) @(posedge clk);
        rst_n = 1;
        $display("--- Reset Released ---");

        // 1. Fill the FIFO
        $display("--- Filling FIFO ---");
        for (int i = 1; i <= Q_DEPTH; i++) begin
            push_entry(i * 10);
        end
        
        if (full) $display("Success: FIFO is Full");

        // 2. Pop all entries
        $display("--- Emptying FIFO ---");
        repeat (Q_DEPTH) begin
            $display("Reading Data: %h", instr_out);
            pop_entry();
        end

        if (empty) $display("Success: FIFO is Empty");

        // 3. Simultaneous Push and Pop
        $display("--- Testing Simultaneous Push/Pop ---");
        push_entry(32'hDEADBEEF); // Put one in first
        @(posedge clk);
        #1;
        push = 1'b1;
        pop  = 1'b1;
        instr_in = 32'hFEEDFACE;
        @(posedge clk);
        #1;
        push = 1'b0;
        pop  = 1'b0;
        $display("Simultaneous action complete. Count should be 1. Count is: %d", dut.count);

        // 4. Flush Test
        $display("--- Testing Flush ---");
        push_entry(32'hAAAA_AAAA);
        push_entry(32'hBBBB_BBBB);
        @(posedge clk);
        #1 flush = 1'b1;
        @(posedge clk);
        #1 flush = 1'b0;
        
        if (empty && dut.count == 0) $display("Success: Flush cleared pointers and count");

        #50;
        $display("--- Simulation Finished ---");
        $finish;
    end

endmodule