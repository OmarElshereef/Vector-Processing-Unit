module in_node #(parameter DATA_WIDTH = 8)(
    input [DATA_WIDTH-1:0] data_in,
    input control_signal,
    output [DATA_WIDTH-1:0] data_out_1,
    output [DATA_WIDTH-1:0] data_out_2
);
    // If control_signal is 0, data goes to data_out_1; if 1, it goes to data_out_2
    assign data_out_1 = control_signal ? {DATA_WIDTH{1'b0}}: data_in;
    assign data_out_2 = control_signal ? data_in : {DATA_WIDTH{1'b0}};
endmodule