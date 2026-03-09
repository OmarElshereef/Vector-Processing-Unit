module scoreboard (
    input logic clk,
    input logic rst_n,
    
    // Check interface (from Decoder)
    input logic [4:0] vd_check, vs1_check, vs2_check,
    input logic       vd_valid, vs1_valid, vs2_valid,
    input logic vm,
    
    // Status interface
    input logic       instr_issued,   // High when instruction moves to Sequencer
    input logic       clear_registers, // High when Lanes finish
    input logic [4:0] vd_clear, vs1_clear, vs2_clear       // Which register to free up
    
    output logic is_valid_instr
);

    logic [31:0] read_reg, write_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_reg <= 32'b0;
            write_reg <= 32'b0;
        end else begin
            // 1. Clear completed register
            if (clear_registers) begin
                write_reg[vd_clear] <= 1'b0;
                read_reg[vs1_clear] <= 1'b0;
                read_reg[vs2_clear] <= 1'b0;
            end
            
            // 2. Mark new destination as busy (Set wins over Clear for same reg)
            if (instr_issued) begin
                write_reg[vd_check] <= 1'b1;
                read_reg[vs1_check] <= 1'b1;
                read_reg[vs2_check] <= 1'b1;
            end
        end
    end

    // 3. Hazard Detection Logic
    always_comb begin
        // Block if any source or destination is currently busy
        if ((vd_valid && (write_reg[vd_check] ||read_reg[vd_check])) ||
            (vs1_valid &&  (read_reg[vs1_check] || write_reg[vs1_check])) ||
            (vs2_valid &&  (read_reg[vs2_check] || write_reg[vs2_check])) ||
            (vm && (read_reg[0] || write_reg[0])))
        begin
            is_valid_instr = 1'b0; // Hazard detected, block instruction
        end else begin
            is_valid_instr = 1'b1; // No hazard, instruction can proceed
        end
    end
    
endmodule
     