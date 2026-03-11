import RISCV_PKG::*;

module mem_cntrl (
    
    // From decoder and configuration
    input clk,
    input start,    // Signal to start the memory operation
    input stride_dir, // 0 for positive stride, 1 for negative stride
    input [2:0] stride,  // Stride (e.g., 0 for 1-byte, 1 for 2-byte, 2 for 4-byte, 3 for 8-byte)
    input [BYTE-1:0] vlb, // Vector length to determine how many elements to process (in bytes)
    input [BYTE-1:0] address, // Base address for memory access
    input mode, // 1 for load, 0 for store, Used for DROM and LSDO
    input [2:0] SEW,
    input [OFFSET_W-1:0] offset,
    
    // From/to memory
    inout [MLENB-1:0][BYTE-1:0] data_mem,
    output [MLENB-1:0] valid_out_mem,
    output [BYTE-1:0] address_out, // Address output for memory access
    
    // From/to VRF
    inout [MLENB-1:0][BYTE-1:0] data_vrf,
    output [MLENB-1:0] valid_out_vrf,

    output running, // Indicates if the memory operation is currently running
    output result_ready // Indicates if the result is ready
);

    reg ended;
    assign result_ready = ended;
    reg [31:0] cycle_count;
    reg [31:0] element_per_cycle;
    reg [31:0] total_cycles;

    reg running_reg; // Indicates if the memory operation is currently running
    assign running = running_reg;

    reg [2:0] stride_reg;  // log2 of stride in bytes
    reg stride_dir_reg;
    reg mode_reg;
    reg [2:0] SEW_reg;
    reg [OFFSET_W-1:0] offset_reg;
    reg [MLENB-1:0][BYTE-1:0] data_buffer;
    reg [MLENB-1:0] valid_buffer;
    reg [BYTE-1:0] shift_reg;
    reg [BYTE-1:0] address_reg;

    wire mode_wire = start ? mode : mode_reg;

    wire [MLENB-1:0] lsdo_valid_out;
    wire [MLENB-1:0][BYTE-1:0] lsdo_out;

    always @(posedge clk) begin
        if (start) begin
            running_reg <= 1;
            mode_reg <= mode;
            SEW_reg <= SEW;
            offset_reg <= offset;
            shift_reg <= 0; // Initialize shift to 0 at the start of the operation
            valid_buffer <= {MLENB{1'b0}}; // Clear valid buffer for load operations
            if(mode) begin
                data_buffer <= {MLENB{8'b0}}; // Clear buffer for load operations
            end else begin
                data_buffer <= data_vrf; // Load data from VRF for store operations
            end
            // Calculate the number of cycles needed for strided access
            element_per_cycle <= ((MLENB-offset) >> stride) << SEW; // Calculate how many elements can be processed per cycle
            total_cycles <= ((vlb) + (((MLENB-offset) >> stride) << SEW) - 1) / (((MLENB-offset) >> stride) << SEW); // Ceiling division for total cycles needed
            cycle_count <= 0;
            stride_dir_reg <= stride_dir; // Set direction based on input
            stride_reg <= stride; // Store the stride for control logic
            if(stride_dir == 0) begin
                address_reg <= address; // Start from base address for positive stride
            end else begin
                address_reg <= address - MLENB; // Start from the last element for negative stride
            end
            ended <= 0;
        end else if (ended != 1) begin
            cycle_count <= cycle_count + 1;
            if (cycle_count == total_cycles - 1) begin
                ended <= 1;
                running_reg <= 0;
            end else begin
                shift_reg <= shift_reg + element_per_cycle; // Increment shift for strided access
                if(stride_dir_reg == 0) begin
                    address_reg <= address_reg + MLENB; // Move to the next set of elements for positive stride
                end else begin
                    address_reg <= address_reg - MLENB; // Move to the next set of elements for negative stride
                end
            end
        end else begin
            running_reg <= 0;
            ended <= 0;
        end
        // Update buffers for load mode
        if (mode_wire) begin
            for(int i=0; i<MLENB; i=i+1) begin
                if (lsdo_valid_out[i]) begin
                    data_buffer[i] <= lsdo_out[i];
                    valid_buffer[i] <= 1'b1;
                end
            end
        end
    end

    LSDO lsdo_inst (
        .data_in(mode_wire ? data_mem : data_buffer), // For load, input is from memory; for store, input is from data buffer
        // .clk(clk),
        .data_dir(stride_dir_reg),
        .shift(shift_reg),
        .mode(mode_wire),
        .SEW(SEW_reg),
        .offset(offset_reg),
        .stride(stride_reg),
        .data_out(lsdo_out),
        .valid_out(lsdo_valid_out)
    );

    assign data_vrf = (mode_wire & ended) ? data_buffer : {MLENB{8'bz}}; // Drive data to VRF for load, high impedance for store
    assign valid_out_vrf = (mode_wire & ended) ? valid_buffer : {MLENB{1'b0}}; // Drive valid signals to VRF for load, low for store

    assign address_out = address_reg;
    assign data_mem = (~mode_wire) ? lsdo_out : {MLENB{8'bz}}; // Drive data to memory for store, high impedance for load
    assign valid_out_mem = (~mode_wire) ? lsdo_valid_out : {MLENB{1'b0}}; // Drive valid signals to memory for store, low for load

endmodule