module switch_node #(parameter DATA_WIDTH = 8)(
    input [DATA_WIDTH-1:0] data_in_1,
    input [DATA_WIDTH-1:0] data_in_2,
    input control_signal,
    output [DATA_WIDTH-1:0] data_out_1,
    output [DATA_WIDTH-1:0] data_out_2
);
    // If control_signal is 0, data_in_1 goes to data_out_1 and data_in_2 goes to data_out_2
    // If control_signal is 1, data_in_1 goes to data_out_2 and data_in_2 goes to data_out_1
    assign data_out_1 = control_signal ? data_in_2 : data_in_1;
    assign data_out_2 = control_signal ? data_in_1 : data_in_2;
endmodule