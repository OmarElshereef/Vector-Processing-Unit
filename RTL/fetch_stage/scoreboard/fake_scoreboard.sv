module fake_scoreboard (
    input  logic clk,
    input  logic rst_n,
    input  logic instr_issued,    // From DispatchQ/Sequencer
    input  logic instr_finished,  // From Sequencer (last chunk done)
    output logic is_valid_instr   // To DispatchQ
);

    logic busy;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) busy <= 1'b0;
        else if (instr_issued)   busy <= 1'b1;
        else if (instr_finished) busy <= 1'b0;
    end


    assign is_valid_instr = !busy;

endmodule