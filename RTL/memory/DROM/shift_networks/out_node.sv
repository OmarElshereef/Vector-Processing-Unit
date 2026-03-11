module out_node #(parameter DATA_WIDTH = 8)(
    input [DATA_WIDTH-1:0] data_in_1,
    input [DATA_WIDTH-1:0] data_in_2,
    output [DATA_WIDTH-1:0] data_out
);
    // Output node simply forwards data_in_1 to data_out, ignoring data_in_2
    assign data_out = data_in_1[DATA_WIDTH-1] ? data_in_1 : data_in_2; // Use MSB of data_in_1 as valid bit
endmodule