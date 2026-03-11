//Gather shift network
import RISCV_PKG::*;

module gsn # (parameter WIDTH = 9) (
    // Input and ouput contain validiation bits at BYTE position
    input [MLENB-1:0][WIDTH-1:0] data_in,
    input [NUM_LAYERS-1:0][MLENB-1:0] controls,
    output [MLENB-1:0][WIDTH-1:0] data_out
);

    wire [2*MLENB-1:0][WIDTH-1:0] layer_data [0:NUM_LAYERS];

    for (genvar elem = 0; elem < MLENB; elem = elem + 1) begin : elements
        // Determine source index based on control signal
        in_node #(WIDTH) node_inst (
            .data_in(data_in[elem]),
            .control_signal(controls[0][elem]),
            .data_out_1(layer_data[0][2*elem]),
            .data_out_2(layer_data[0][2*elem+1])
        );
    end

    for (genvar layer = 1; layer < NUM_LAYERS; layer = layer + 1) begin : layers
        for (genvar elem = 0; elem < MLENB; elem = elem + 1) begin : elements
            // Determine source index based on control signal
            if((1<<layer) + 2*elem+1 < 2*MLENB)begin
                switch_node #(WIDTH) node_inst (
                    .data_in_1(layer_data[layer-1][2*elem]),
                    .data_in_2(layer_data[layer-1][(1<<layer) + 2*elem+1]),
                    .control_signal(controls[layer][elem]),
                    .data_out_1(layer_data[layer][2*elem]),
                    .data_out_2(layer_data[layer][2*elem+1])
                );
            end
            else begin
                switch_node #(WIDTH) node_inst (
                    .data_in_1(layer_data[layer-1][2*elem]),
                    .data_in_2({(WIDTH){1'b0}}), // No valid data, use zero
                    .control_signal(controls[layer][elem]),
                    .data_out_1(layer_data[layer][2*elem]),
                    .data_out_2(layer_data[layer][2*elem+1])
                );
            end
        end
    end
    
    for (genvar elem = 0; elem < MLENB; elem = elem + 1) begin : output_assign
        // Determine source index based on control signal
        out_node #(WIDTH) node_inst (
            .data_in_1(layer_data[NUM_LAYERS-1][2*elem]),
            .data_in_2(((1<<(NUM_LAYERS)) + 2*elem+1 < 2*MLENB) ? layer_data[NUM_LAYERS-1][(1<<(NUM_LAYERS)) + 2*elem+1] : {(WIDTH){1'b0}}), // No valid data, use zero
            .data_out(data_out[elem])
        );
    end
endmodule
