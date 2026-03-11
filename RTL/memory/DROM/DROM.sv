import RISCV_PKG::*;

module DROM (
    // Input and ouput contain validiation bits at BYTE position
    input [MLENB-1:0][BYTE-1:0] data_in,
    input [2:0] stride,                 // Stride (e.g., 0 for 1-byte, 1 for 2-byte, 2 for 4-byte, 3 for 8-byte)
    input [2:0] SEW,                    // SEW encoded as 3 bits (0=8-bit, 1=16-bit, 2=32-bit, 3=64-bit, etc.)
    input [OFFSET_W-1:0] offset,        // Offset within the memory line
    input mode,                         // 0 for scatter, 1 for gather
    // input clk,
    output [MLENB-1:0][BYTE-1:0] data_out,
    // output wire [MLENB-1:0][BYTE:0] valid_wire, // For debugging: valid bits from control SSN
    // output wire [NUM_LAYERS:0][MLENB-1:0] Ctrl_wire, // For debugging: control signals from SCG
    // output [MLENB-1:0] valid_pos,
    output [MLENB-1:0] valid_out
);

    wire [NUM_LAYERS:0][MLENB-1:0] Ctrl_wire;
    wire [MLENB-1:0] valid_wire;
    wire [MLENB-1:0] valid_pos;
    reg [NUM_LAYERS-1:0][MLENB-1:0] Ctrl_buff;
    reg [MLENB-1:0][BYTE:0] Data_buff; // kept as reg for always_comb

    scg scg_inst (
        .stride(stride),
        .SEW(SEW),
        .offset(offset),
        .valid_pos(valid_pos),
        .controls(Ctrl_wire)
    );

    ssn #(.WIDTH(1)) ctrl_ssn (
        .data_in(valid_pos),
        .controls(Ctrl_wire[NUM_LAYERS-1:0]),
        .data_out(valid_wire)
    );

    // always @(posedge clk) begin
    //     for (int i = 0; i < NUM_LAYERS; i++) begin
    //         Ctrl_buff[i] = (mode == 0) ? Ctrl_wire[i] : Ctrl_wire[NUM_LAYERS - i];
    //     end
    //     for (int i = 0; i < MLENB; i++) begin
    //         Data_buff[i] = (mode == 0) ? {valid_pos[i], data_in[i]} : {valid_wire[i], data_in[i]};
    //     end
    // end

    always_comb begin
        for (int i = 0; i < NUM_LAYERS; i++) begin
            Ctrl_buff[i] = (mode == 0) ? Ctrl_wire[i] : Ctrl_wire[NUM_LAYERS - i];
        end
        for (int i = 0; i < MLENB; i++) begin
            // For scatter, we keep the original data; for gather, we use the valid bits from the control SSN
            Data_buff[i] = (mode == 0) ? {valid_pos[i], data_in[i]} : {valid_wire[i], data_in[i]};
        end
    end

    reg [MLENB-1:0][BYTE:0] Scatter_data; 
    reg [MLENB-1:0][BYTE:0] Gather_data;

    ssn #(.WIDTH(BYTE+1)) data_ssn (
        .data_in(Data_buff),
        .controls(Ctrl_buff),
        .data_out(Scatter_data)
    );

    gsn #(.WIDTH(BYTE+1)) data_gsn (
        .data_in(Data_buff),
        .controls(Ctrl_buff),
        .data_out(Gather_data)
    );

    genvar i;
    generate
        for (i = 0; i < MLENB; i++) begin : data_assign
            wire [BYTE:0] selected = (mode == 0) ? Scatter_data[i] : Gather_data[i];
            // Can be optimized to avoid unnecessary zeroing if the valid is used for later verification only, but for clarity we will keep it this way
            assign data_out[i] = selected[BYTE] ? selected[BYTE-1:0] : {(BYTE){1'b0}}; 
            assign valid_out[i] = selected[BYTE];
        end
    endgenerate
    
endmodule