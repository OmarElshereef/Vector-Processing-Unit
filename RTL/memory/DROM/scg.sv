//Shift Count Generation
import RISCV_PKG::*;

module scg (
    input [2:0] stride,                 // Stride (e.g., 0 for 1-byte, 1 for 2-byte, 2 for 4-byte, 3 for 8-byte)
    input [2:0] SEW,                  // SEW encoded as 3 bits (0=8-bit, 1=16-bit, 2=32-bit, 3=64-bit, etc.)
    input [OFFSET_W-1:0] offset,        // Offset within the memory line
    output [MLENB-1:0] valid_pos,
    output [NUM_LAYERS:0][MLENB-1:0] controls
    // ,output [BYTE-1:0] intermediate_positions [0:NUM_LAYERS][MLENB-1:0] // For debugging: positions at each layer
);
    
    // Step 1: Calculate (stride - EEWB) × i using shift and add operations
    wire [BYTE-1:0] diff;
    wire [BYTE-1:0] EEWB = (1 << SEW); // EEWB = 2^SEW
    assign diff = (1 << stride) - EEWB;    

    // Pre-compute all possible power-of-2 shifts (reused across all elements)
    wire [BYTE-1:0] shifted_diff [0:BYTE-1];
    genvar bit_pos;
    generate
        for (bit_pos = 0; bit_pos < BYTE; bit_pos = bit_pos + 1) begin : gen_shifts
            assign shifted_diff[bit_pos] = diff << bit_pos;
        end
    endgenerate

    // For each element i, add the shifted values where bit i is set
    wire [BYTE-1:0] shift_base [0:MLENB-1];
    genvar i;
    generate
        for (i = 0; i < MLENB; i = i + 1) begin : calc_positions
            // Optimized shift and add: reuse pre-computed shifts
            // Hardware: 8 shifters shared across 64 elements + adder tree per element
            localparam [BYTE-1:0] I_CONST = i;
            
            assign shift_base[i] = ((I_CONST[0]) ? shifted_diff[0] : 8'b0) +
                                   ((I_CONST[1]) ? shifted_diff[1] : 8'b0) +
                                   ((I_CONST[2]) ? shifted_diff[2] : 8'b0) +
                                   ((I_CONST[3]) ? shifted_diff[3] : 8'b0) +
                                   ((I_CONST[4]) ? shifted_diff[4] : 8'b0) +
                                   ((I_CONST[5]) ? shifted_diff[5] : 8'b0) +
                                   ((I_CONST[6]) ? shifted_diff[6] : 8'b0) +
                                   ((I_CONST[7]) ? shifted_diff[7] : 8'b0);
        end
    endgenerate
    
    // Step 2: Add offset to generate final position values
    wire [BYTE-1:0] shift_steps [0:MLENB-1];
    
    generate
        for (i = 0; i < MLENB; i = i + 1) begin : add_offset
            assign shift_steps[i] = (i < (MLENB >> stride)) ? shift_base[i] + offset : {BYTE{1'b0}}; // Zero out positions that exceed the number of elements
        end
    endgenerate
    

    // Step 3: Generate control signals for each layer based on position values
    wire [BYTE-1:0] shifts [0:MLENB-1];
    wire [MLENB-1:0][NUM_LAYERS:0] final_shifts;
    generate
        for (i = 0; i < MLENB; i = i + 1) begin : select_shifts
            wire [BYTE-1:0] xored;
            
            assign shifts[i] = shift_steps[i >> SEW];
            assign xored = shifts[i] ^ (shifts[i] << 1);
            assign final_shifts[i] = xored[BYTE-2:0];
        end
    endgenerate

    // Step 5: Calculate all positions including initial, intermediate power-of-2 steps, and final
    wire [BYTE-1:0] intermediate_positions [0:NUM_LAYERS][0:MLENB-1];
    wire [BYTE-1:0] inverse_EEWB = ~(EEWB - 1);
    generate
        for (i = 0; i < MLENB; i = i + 1) begin : calc_steps
            // Initial position
            wire [BYTE-1:0] final_pos;
            assign final_pos = shifts[i] + EEWB + (i & inverse_EEWB);
            assign intermediate_positions[0][i] = i;
            genvar step;
            for (step = 0; step < NUM_LAYERS; step = step + 1) begin : power_of_2_steps
                // Accumulate from MSB to LSB: bit index = (NUM_LAYERS - 1 - step)
                wire [BYTE-1:0] accumulated_shift;
                assign accumulated_shift = (final_pos <= MLENB) && shifts[i][NUM_LAYERS - 1 - step] ? (1 << (NUM_LAYERS - 1 - step)) : 8'd0; // Zero out shifts that would exceed the memory line
                assign intermediate_positions[step+1][i] = intermediate_positions[step][i] + accumulated_shift;
            end
        end
    endgenerate
    

    // Generate control signals for each layer based on shift counts
    // Use intermediate positions to index into controls array
    reg [NUM_LAYERS:0][MLENB-1:0] control_regs;
    reg [MLENB-1:0] valid_pos_reg;

    always_comb begin
        control_regs= '0;
        valid_pos_reg = '0;
        // Set control signals at intermediate positions
        for (int i = 0; i < (MLENB >> (stride - SEW)); i = i + 1) begin
            valid_pos_reg[i] = 1'b1;
            for (int layer = 0; layer < NUM_LAYERS+1; layer = layer + 1) begin
                control_regs[layer][intermediate_positions[layer][i]] |= final_shifts[i][NUM_LAYERS-layer];
            end   
        end
    end
    assign controls = control_regs;
    assign valid_pos = valid_pos_reg;
    
endmodule