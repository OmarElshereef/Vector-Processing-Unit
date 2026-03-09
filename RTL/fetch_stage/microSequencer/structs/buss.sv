package vec_uop_pkg;

    // -------------------------------------------------------------------------
    // Functional unit target — tells downstream which unit should handle this uop
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        FU_ALU      = 2'b00,    // Vector arithmetic (vadd, vmul, vwmacc, etc.)
        FU_LOAD     = 2'b01,    // Vector load
        FU_STORE    = 2'b10,    // Vector store
        FU_MASK     = 2'b11     // Mask operations
    } fu_t;

    typedef struct packed {

        logic           valid;

        // --- Functional unit ---
        fu_t            fu;             // Which functional unit handles this uop

        // --- Opcode ---
        // Carry the original opcode through — each FU decodes what it needs
        logic [6:0]     opcode;         // RVV major opcode (from instruction [6:0])
        logic [2:0]     funct3;         // Instruction funct3 field
        logic [5:0]     funct6;         // Instruction funct6 field

        // --- Register numbers (architectural, 5-bit, v0–v31) ---
        logic [4:0]     vs1;            // Source register 1
        logic [4:0]     vs2;            // Source register 2
        logic [4:0]     vd;             // Destination register

        // --- Element pointer info (from element_pointer module) ---
        logic [9:0]     chunk_index;    // Current element index (start of this chunk)
        logic           last_chunk;     // This is the final chunk of the instruction

        // --- Lane control ---
        logic [3:0]     active_lanes;   // Which lanes have live elements this chunk
                                        // Matches NO_LANES — adjust width to your param

        // --- Element width ---
        logic [6:0]     eew;            // Effective element width in bits (8/16/32/64)
                                        // From vtype_decoder

        // --- Mask control ---
        logic           mask_en;        // 1 = v0 mask is active for this instruction
                                        // 0 = unmasked (all elements active)

        // --- Policy flags (from vtype_decoder) ---
        logic           vta;            // Tail agnostic policy
        logic           vma;            // Mask agnostic policy

    } vec_uop_t;

endpackage