module dispatchQ #(
    parameter INSTR_WIDTH     = 32,
    parameter SCALAR_VAL_SIZE = 32,
    parameter ID_WIDTH        = 5,
    parameter Q_DEPTH         = 8, 
    parameter VTYPE_WIDTH     = 8,
    parameter VL_WIDTH        = 32
) (
    input  logic clk,
    input  logic rst_n,
    input  logic flush,

    // Scalar Interface
    input  logic                      push,
    input  logic [INSTR_WIDTH-1:0]    instr_in,
    input  logic [SCALAR_VAL_SIZE-1:0] rs1_value_in,
    input  logic [SCALAR_VAL_SIZE-1:0] rs2_value_in,
    input  logic [ID_WIDTH-1:0]       instr_id_in,
    input  logic [VTYPE_WIDTH-1:0]    vtype_in,
    input  logic [VL_WIDTH-1:0]       vl_in,
    output logic                      full,

    // VPU Interface
    input  logic                      pop,
    output logic                      empty,
    output logic [INSTR_WIDTH-1:0]    instr_out,
    output logic [SCALAR_VAL_SIZE-1:0] rs1_value_out,
    output logic [SCALAR_VAL_SIZE-1:0] rs2_value_out,
    output logic [ID_WIDTH-1:0]       instr_id_out,
    output logic [VTYPE_WIDTH-1:0]    vtype_out,
    output logic [VL_WIDTH-1:0]       vl_out
);

    localparam ADDR_WIDTH = $clog2(Q_DEPTH);

    

    // Using a struct for cleaner synthesis and debugging
    typedef struct packed {
        logic [INSTR_WIDTH-1:0]     instr;
        logic [SCALAR_VAL_SIZE-1:0] rs1;
        logic [SCALAR_VAL_SIZE-1:0] rs2;
        logic [ID_WIDTH-1:0]        id;
        logic [VTYPE_WIDTH-1:0]     vtype;
        logic [VL_WIDTH-1:0]        vl;
    } vpu_packet_t;

    vpu_packet_t instr_queue [Q_DEPTH-1:0];
    logic [ADDR_WIDTH-1:0] r_ptr, w_ptr;
    logic [ADDR_WIDTH:0]   count;


    assign full  = (count == Q_DEPTH);
    assign empty = (count == 0);

    // Continuous assignment of the struct fields to output ports
    vpu_packet_t current_out;
    assign current_out   = instr_queue[r_ptr];
    assign instr_out     = empty ? '0 :current_out.instr;
    assign rs1_value_out = empty ? '0 :current_out.rs1;
    assign rs2_value_out = empty ? '0 :current_out.rs2;
    assign instr_id_out  = empty ? '0 :current_out.id;
    assign vtype_out     = empty ? '0 :current_out.vtype;
    assign vl_out        = empty ? '0 :current_out.vl;

    // Using always_ff for synthesis intent
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_ptr <= '0;
            w_ptr <= '0;
            count <= '0;
        end else if (flush) begin
            r_ptr <= '0;
            w_ptr <= '0;
            count <= '0;
        end else begin
            unique case ({ (push && !full), (pop && !empty) })
                2'b10: begin // Push Only
                    instr_queue[w_ptr] <= vpu_packet_t'{
                        instr: instr_in,
                        rs1:   rs1_value_in,
                        rs2:   rs2_value_in,
                        id:    instr_id_in,
                        vtype: vtype_in,
                        vl:    vl_in
                    };
                    w_ptr <= (w_ptr == ADDR_WIDTH'(Q_DEPTH-1)) ? '0 : w_ptr + 1'b1;
                    count <= count + 1'b1;
                end
                2'b01: begin // Pop Only
                    r_ptr <= (r_ptr == ADDR_WIDTH'(Q_DEPTH-1)) ? '0 : r_ptr + 1'b1;
                    count <= count - 1'b1;
                end
                2'b11: begin // Both
                    instr_queue[w_ptr] <= vpu_packet_t'{
                        instr: instr_in,
                        rs1:   rs1_value_in,
                        rs2:   rs2_value_in,
                        id:    instr_id_in,
                        vtype: vtype_in,
                        vl:    vl_in
                    };
                    w_ptr <= (w_ptr == ADDR_WIDTH'(Q_DEPTH-1)) ? '0 : w_ptr + 1'b1;
                    r_ptr <= (r_ptr == ADDR_WIDTH'(Q_DEPTH-1)) ? '0 : r_ptr + 1'b1;
                end
                default: ; 
            endcase
        end
    end

endmodule