module executeStage #(
    parameter VLEN       = 512,  // Vector register length in bits
    parameter ELEN       = 64,   // Maximum element width in bits
    parameter REG_COUNT  = 32,   // Number of vector registers (v0-v31)
    parameter UNIT_WIDTH = 16,   // Arithmetic sub-unit granularity
    
    // Derived parameters
    parameter ADDR_WIDTH = $clog2(REG_COUNT),
    parameter SEW_BITS   = $clog2($clog2(VLEN/UNIT_WIDTH) + 1),
    parameter FINAL_BITS = (SEW_BITS < 1) ? 1 : SEW_BITS
)(
    input  wire                  clk,
    input  wire                  rst,
    input  wire			 is_signed,
    input  wire                  instr_valid,
    
    input  wire [ADDR_WIDTH-1:0] vs1_addr,
    input  wire [ADDR_WIDTH-1:0] vs2_addr,
    input  wire [ADDR_WIDTH-1:0] vd_addr,
    
    input  wire [FINAL_BITS:0]   eew_log2,
    
    input  wire [2:0]            opcode,
    
    // Write port
    input  wire                  write_en,
    input  wire [VLEN-1:0]       write_data,
    input  wire [ADDR_WIDTH-1:0] write_addr,
    
    input wire [LANE_COUNT-1:0] lane_mask,
    input wire                  mask_en,
    
    // Result output
    output wire [VLEN-1:0]       result,
    output wire [2*VLEN-1:0]	 result_wide
);

    // Fixed lane count based on maximum element width
    localparam LANE_COUNT = VLEN / ELEN;
    
    // Maximum element subdivisions within a lane
    localparam LANE_MAX_ELEN = $clog2(ELEN / UNIT_WIDTH);

    // Cross-lane operation detection
    wire cross_lane = (eew_log2 > LANE_MAX_ELEN);

    wire is_arith = (opcode == 3'd0 || opcode == 3'd1);
    wire first_lane_carry = is_arith & (opcode == 3'd1);

    //-------- internal wires --------//
    wire [ADDR_WIDTH-1:0] read_addr_to_mem;
    wire                  read_en_to_mem;
    wire                  latch_en_to_lane;
    wire [VLEN-1:0]       operand_to_lane;

    wire [LANE_COUNT:0] carry_chain;
    
    wire [VLEN-1:0] v0_mask_data;
    
   //-------- control unit --------//
    executeControlUnit #(
        .ADDR_WIDTH (ADDR_WIDTH)
    ) CU (
        .clk         (clk),
        .rst         (rst),
        .instr_valid (instr_valid),
        .rs1         (vs1_addr),
        .rs2         (vs2_addr),
        .read_addr   (read_addr_to_mem),
        .read_en     (read_en_to_mem),
        .latch_en    (latch_en_to_lane)
    );

    //-------- register memory --------//
    regMemory #(
        .VLEN       (VLEN),
        .ELEN (ELEN),
        .REG_COUNT  (REG_COUNT),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) memoryBanks (
        .clk        (clk),
        .rst        (rst),
        .read_en    (read_en_to_mem),
        .write_en   (write_en),
        .read_addr  (read_addr_to_mem),
        .write_addr (write_addr),
        .write_data (write_data),
        .out        (operand_to_lane),
        .lane_mask (lane_mask),
        .mask_en (mask_en),
        .v0_mask(v0_mask_data)
    );

    //-------- carry chain entry point --------//
    // Lane 0 gets the arithmetic initial carry (1 for SUB, 0 for ADD/logic)
    // When cross_lane=0 every lane gets this same value as its fresh start
    assign carry_chain[0] = first_lane_carry;

    reg latch_en_delayed;
    always @(posedge clk or posedge rst) begin
        if (rst) latch_en_delayed <= 0;
        else     latch_en_delayed <= latch_en_to_lane;
    end

    //-------- lane generation + carry guards --------//
    genvar i;
    generate
        for (i = 0; i < LANE_COUNT; i = i + 1) begin : gen_lanes

            // Guard logic ? decides what carry_in this lane receives:
            //   cross_lane=1 (element spans lanes): pass carry from previous lane
            //   cross_lane=0 (element fits in lane): each lane restarts fresh
            //     SUB restart = 1 only for lane 0 (first_lane_carry handles that)
            //     all other lanes restart at 0 for ADD, 0 for logic
            // When cross_lane=0 and i>0: inject 0 for ADD, 0 for logic
            // Lane 0 always uses carry_chain[0] which is first_lane_carry
            wire guarded_carry;
            if (i == 0) begin
                // Lane 0: always use the chain entry (first_lane_carry)
                assign guarded_carry = carry_chain[0];
            end else begin
                // Lane i>0:
                //   cross_lane=1 ? forward carry_chain[i] (output of lane i-1)
                //   cross_lane=0 ? inject 0 (each lane is independent,
                //                  SUB borrow restarts fresh per element boundary
                //                  which addModule handles internally via carry_bus[0])
                assign guarded_carry = cross_lane ? carry_chain[i] : 1'b0;
            end

            executeLane #(
                .LANE_WIDTH      (ELEN),
                .UNIT_WIDTH  (UNIT_WIDTH),
                .SEW_BITS  (SEW_BITS),
                .FINAL_BITS (FINAL_BITS)
            ) lane_inst (
                .clk           (clk),
                .latch_en      (latch_en_delayed),
		.is_signed     (is_signed),
                .chained_carry (guarded_carry),
                .eew_log2          (eew_log2),
                .operand       (operand_to_lane[i*ELEN +: ELEN]),
                .opcode        (opcode),
                .result        (result[i*ELEN +: ELEN]),
		.result_wide   (result_wide[2*i*ELEN +: 2*ELEN]),
                .carry_out     (carry_chain[i+1])
            );
        end
    endgenerate

endmodule