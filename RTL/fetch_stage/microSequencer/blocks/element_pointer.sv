module element_pointer #(
    parameters
    NO_LANES = 4,
    VLEN = 256,
    VL_WIDTH = 10
) (
    ports
    input logic clk,
    input logic rst_n,

    input logic start_vloop,
    input logic [VL_WIDTH-1:0] vl_in,
    input logic advance_loop,


    output logic [VL_WIDTH-1:0] current_index,
    output logic [NO_LANES-1:0] active_lanes
    output logic last_chunk,
    output logic loop_done
);
    logic [VL_WIDTH-1:0] count;

    always_ff @( posedge clk or negedge rst_n ) begin
        if (!rst_n) begin
            count <= '0;
        end else if (start_vloop) begin
            count <= '0;
        end else if (advance_loop) begin
            count <= count + NO_LANES;
        end 
        
    end

    assign current_index = count;

    // Calculate active lanes based on remaining elements
    always_comb begin
        for (int i =0 ;i< NO_LANES ;i++ ) begin
            active_lanes[i] = (count + i < vl_in) ? 1'b1 : 1'b0;
        end
    end

    assign last_chunk = (count + NO_LANES >= vl_in);
    assign loop_done = (count >= vl_in);

endmodule