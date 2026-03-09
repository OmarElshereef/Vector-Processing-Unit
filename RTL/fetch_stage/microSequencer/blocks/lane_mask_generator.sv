module lane_mask_generator #(
    parameters
    NO_LANES = 4,
    VLEN = 256,
    VL_WIDTH = 10
) (
    ports
    input logic [VL_WIDTH-1:0 ] current_index,
    input logic [VL_WIDTH-1:0] vl_in,
);
    
endmodule    