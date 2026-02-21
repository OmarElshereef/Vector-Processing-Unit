module executeStage #(
    parameter WIDTH      = 512,
    parameter ELEN_WIDTH = 64,
    parameter REG_COUNT  = 32,
    parameter ADDR_WIDTH = $clog2(REG_COUNT),
    parameter UNIT_WIDTH = 16,
    parameter ELEN_BITS  = $clog2($clog2(WIDTH/UNIT_WIDTH) + 1),
    parameter FINAL_BITS = (ELEN_BITS < 1) ? 1 : ELEN_BITS
)(
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  instr_valid,
    input  wire [ADDR_WIDTH-1:0] src1,
    input  wire [ADDR_WIDTH-1:0] src2,
    input  wire [ADDR_WIDTH-1:0] dst,
    input  wire [FINAL_BITS:0]   elen,
    input  wire [2:0]            opcode,
    input  wire                  write_en,
    input  wire [WIDTH-1:0]      write_data,
    input  wire [ADDR_WIDTH-1:0] write_addr,
    output wire [WIDTH-1:0]      result
);
    localparam LANE_COUNT = WIDTH / ELEN_WIDTH;
    localparam LANE_MAX_ELEN = $clog2(ELEN_WIDTH / UNIT_WIDTH);

    wire cross_lane = (elen > LANE_MAX_ELEN);

    wire is_arith = (opcode == 3'd0 || opcode == 3'd1);

    wire first_lane_carry = is_arith & (opcode == 3'd1);

    //-------- internal wires --------//
    wire [ADDR_WIDTH-1:0] read_addr_to_mem;
    wire                  read_en_to_mem;
    wire                  latch_en_to_lane;
    wire [WIDTH-1:0]      operand_to_lane;

    wire [LANE_COUNT:0] carry_chain;

    //-------- control unit --------//
    executeControlUnit #(
        .ADDR_WIDTH (ADDR_WIDTH)
    ) CU (
        .clk         (clk),
        .rst         (rst),
        .instr_valid (instr_valid),
        .rs1         (src1),
        .rs2         (src2),
        .read_addr   (read_addr_to_mem),
        .read_en     (read_en_to_mem),
        .latch_en    (latch_en_to_lane)
    );

    //-------- register memory --------//
    regMemory #(
        .WIDTH      (WIDTH),
        .ELEN_WIDTH (ELEN_WIDTH),
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
        .out        (operand_to_lane)
    );

    //-------- carry chain entry point --------//
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
            wire guarded_carry;
            if (i == 0) begin
                assign guarded_carry = carry_chain[0];
            end else begin
                assign guarded_carry = cross_lane ? carry_chain[i] : 1'b0;
            end

            executeLane #(
                .LENGTH      (ELEN_WIDTH),
                .SUB_LENGTH  (UNIT_WIDTH),
                .ELEN_WIDTH  (ELEN_BITS),
                .FINAL_WIDTH (FINAL_BITS)
            ) lane_inst (
                .clk           (clk),
                .latch_en      (latch_en_delayed),
                .chained_carry (guarded_carry),
                .elen          (elen),
                .operand       (operand_to_lane[i*ELEN_WIDTH +: ELEN_WIDTH]),
                .opcode        (opcode),
                .result        (result[i*ELEN_WIDTH +: ELEN_WIDTH]),
                .carry_out     (carry_chain[i+1])
            );
        end
    endgenerate
endmodule