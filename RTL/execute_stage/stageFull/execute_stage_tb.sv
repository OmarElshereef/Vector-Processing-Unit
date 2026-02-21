`timescale 1ns/1ps
module executeStage_tb;

    localparam WIDTH      = 512;
    localparam ELEN_WIDTH = 64;
    localparam REG_COUNT  = 32;
    localparam ADDR_WIDTH = 5;
    localparam UNIT_WIDTH = 16;
    localparam ELEN_BITS  = $clog2($clog2(WIDTH/UNIT_WIDTH) + 1);
    localparam FINAL_BITS = (ELEN_BITS < 1) ? 1 : ELEN_BITS;
    localparam LANE_COUNT = WIDTH / ELEN_WIDTH;
    localparam LANE_MAX_ELEN = $clog2(ELEN_WIDTH/UNIT_WIDTH); // 2
    localparam MAX_ELEN      = $clog2(WIDTH/UNIT_WIDTH);      // 5

    localparam ADD=3'd0, SUB=3'd1, OR=3'd2, AND=3'd3, NOT=3'd4, XOR=3'd5;

    reg                   clk, rst, instr_valid, write_en;
    reg  [ADDR_WIDTH-1:0] src1, src2, dst, write_addr;
    reg  [FINAL_BITS:0]   elen;
    reg  [2:0]            opcode;
    reg  [WIDTH-1:0]      write_data;
    wire [WIDTH-1:0]      result;

    executeStage #(
        .WIDTH(WIDTH),.ELEN_WIDTH(ELEN_WIDTH),.REG_COUNT(REG_COUNT),
        .ADDR_WIDTH(ADDR_WIDTH),.UNIT_WIDTH(UNIT_WIDTH),
        .ELEN_BITS(ELEN_BITS),.FINAL_BITS(FINAL_BITS)
    ) dut (
        .clk(clk),.rst(rst),.instr_valid(instr_valid),
        .src1(src1),.src2(src2),.dst(dst),.elen(elen),.opcode(opcode),
        .write_en(write_en),.write_data(write_data),
        .write_addr(write_addr),.result(result)
    );

    initial begin clk=0; forever #5 clk=~clk; end

    reg [WIDTH-1:0] shadow [0:REG_COUNT-1];
    integer pass=0, fail=0, suite_pass=0, suite_fail=0, i, j, k;

    // ----------------------------------------------------------------
    // Infrastructure ? same as working base
    // ----------------------------------------------------------------
    task write_reg;
        input [ADDR_WIDTH-1:0] addr;
        input [WIDTH-1:0]      data;
    begin
        shadow[addr] = data;
        @(negedge clk);
        write_addr=addr; write_data=data; write_en=1; instr_valid=0;
        @(negedge clk);
        write_en=0;
        repeat(2) @(negedge clk);
    end
    endtask

    task run;
        input [ADDR_WIDTH-1:0] r1, r2;
        input [2:0]            op;
        input [FINAL_BITS:0]   el;
        input [WIDTH-1:0]      exp;
        input string           name;
        reg [WIDTH-1:0] got;
    begin
        @(negedge clk);
        src1=r1; src2=r2; opcode=op; elen=el; write_en=0; instr_valid=1;
        @(negedge clk); instr_valid=0;
        @(posedge clk);
        @(posedge clk); #1;
        got = result;
        if (got===exp) begin
            pass=pass+1; suite_pass=suite_pass+1;
            $display("[PASS] %s", name);
        end else begin
            fail=fail+1; suite_fail=suite_fail+1;
            $display("[FAIL] %s", name);
            $display("  op=%s elen=%0d",(op==ADD)?"ADD":(op==SUB)?"SUB":
                (op==OR)?"OR":(op==AND)?"AND":(op==NOT)?"NOT":"XOR",el);
            $display("  Exp: 0x%0128h", exp);
            $display("  Got: 0x%0128h", got);
        end
    end
    endtask

    task suite_header;
        input string name;
    begin
        suite_pass=0; suite_fail=0;
        $display("\n================================================================================");
        $display("  %s", name);
        $display("================================================================================");
    end
    endtask

    task suite_footer;
    begin
        $display("  >> Suite: %0d passed, %0d failed", suite_pass, suite_fail);
    end
    endtask

    // ----------------------------------------------------------------
    // Reference model ? same as working base
    // ----------------------------------------------------------------
    function [WIDTH-1:0] f_logic;
        input [WIDTH-1:0] a,b; input [2:0] op;
    begin
        case(op)
            OR:  f_logic=a|b;  AND: f_logic=a&b;
            XOR: f_logic=a^b;  NOT: f_logic=~a;
            default: f_logic=0;
        endcase
    end
    endfunction

    function [WIDTH-1:0] f_arith;
        input [WIDTH-1:0] a1,a2; input is_sub; input integer el;
        integer lane,elem,u,b,esz,epl,safe;
        reg [WIDTH-1:0] rf,om; reg lc,c,lco,Cross; reg[31:0] s1,s2,sm;
    begin
        safe=(UNIT_WIDTH*(1<<el)>ELEN_WIDTH)?LANE_MAX_ELEN:el;
        esz=UNIT_WIDTH*(1<<safe); epl=ELEN_WIDTH/esz;
        Cross=(el>LANE_MAX_ELEN); rf=0; om=is_sub?~a2:a2; lco=is_sub;
        for(lane=0;lane<LANE_COUNT;lane=lane+1) begin
            lc=(lane==0)?lco:(Cross?lco:1'b0);
            for(elem=0;elem<epl;elem=elem+1) begin
                c=(elem==0)?lc:is_sub;
                for(u=0;u<(1<<safe);u=u+1) begin
                    b=lane*ELEN_WIDTH+elem*esz+u*UNIT_WIDTH;
                    s1=(a1>>b)&((1<<UNIT_WIDTH)-1);
                    s2=(om>>b)&((1<<UNIT_WIDTH)-1);
                    sm=s1+s2+c; c=(sm>>UNIT_WIDTH)&1;
                    rf=rf|(((sm&((1<<UNIT_WIDTH)-1))<<b));
                end
                if(elem==epl-1) lco=c^is_sub;
            end
        end
        f_arith=rf;
    end
    endfunction

    function [WIDTH-1:0] fexp;
        input [WIDTH-1:0] a,b; input [2:0] op; input integer el;
    begin
        case(op)
            ADD: fexp=f_arith(a,b,0,el); SUB: fexp=f_arith(a,b,1,el);
            default: fexp=f_logic(a,b,op);
        endcase
    end
    endfunction

    task op;
        input [ADDR_WIDTH-1:0] r1,r2;
        input [2:0] o; input [FINAL_BITS:0] el; input string nm;
    begin
        run(r1,r2,o,el, fexp(shadow[r1],shadow[r2],o,el), nm);
    end
    endtask

    // ----------------------------------------------------------------
    // Load helpers
    // ----------------------------------------------------------------
    task load_uniform;
        input [ADDR_WIDTH-1:0] addr;
        input [ELEN_WIDTH-1:0] lane_val;
        reg [WIDTH-1:0] v; integer ln;
    begin
        v=0;
        for(ln=0;ln<LANE_COUNT;ln=ln+1) v[ln*ELEN_WIDTH +: ELEN_WIDTH]=lane_val;
        write_reg(addr, v);
    end
    endtask

    task load_rand;
        input [ADDR_WIDTH-1:0] addr;
        reg [WIDTH-1:0] v; integer ln;
    begin
        v=0;
        for(ln=0;ln<LANE_COUNT;ln=ln+1) v[ln*ELEN_WIDTH +: ELEN_WIDTH]={$random,$random};
        write_reg(addr, v);
    end
    endtask

    // ================================================================
    // Main
    // ================================================================
    reg [WIDTH-1:0] held;
    reg [2:0] rand_op;
    reg [FINAL_BITS:0] rand_el;
    reg [ADDR_WIDTH-1:0] ra, rb;

    initial begin
        rst=1; instr_valid=0; write_en=0;
        src1=0;src2=0;dst=0;elen=0;opcode=0;write_data=0;write_addr=0;
        for(i=0;i<REG_COUNT;i=i+1) shadow[i]=0;
        repeat(4) @(posedge clk); rst=0; repeat(2) @(posedge clk);

        // Load fixed patterns
        write_reg(0,  {WIDTH{1'b0}});
        load_uniform(1,  64'hAAAAAAAAAAAAAAAA);
        load_uniform(2,  64'h5555555555555555);
        write_reg(3,  {WIDTH{1'b1}});
        load_uniform(4,  64'h0001000100010001);
        load_uniform(5,  64'hFFFFFFFFFFFFFFFF);
        load_uniform(6,  64'hDEADBEEFDEADBEEF);
        load_uniform(7,  64'hCAFEBABECAFEBABE);
        load_uniform(8,  64'hF0F0F0F0F0F0F0F0);
        load_uniform(9,  64'h0F0F0F0F0F0F0F0F);
        load_uniform(10, 64'h8000000000000000);
        load_uniform(11, 64'h7FFFFFFFFFFFFFFF);
        load_uniform(12, 64'hFFFF000000000000);
        load_uniform(13, 64'h00000000FFFFFFFF);
        load_uniform(14, 64'h0000FFFF0000FFFF);
        load_uniform(15, 64'hFFFF0000FFFF0000);
        for(i=16;i<REG_COUNT;i=i+1) load_rand(i);

        // ============================================================
        suite_header("SUITE 1: Logical Ops ? Known Patterns");
        // ============================================================
        op(1,2, OR,  MAX_ELEN, "OR:  AAAA|5555=FFFF");
        op(1,2, AND, MAX_ELEN, "AND: AAAA&5555=0000");
        op(1,2, XOR, MAX_ELEN, "XOR: AAAA^5555=FFFF");
        op(1,0, NOT, MAX_ELEN, "NOT: ~AAAA=5555");
        op(3,0, NOT, MAX_ELEN, "NOT: ~all-ones=0");
        op(0,0, OR,  MAX_ELEN, "OR:  0|0=0");
        op(0,0, AND, MAX_ELEN, "AND: 0&0=0");
        op(0,0, XOR, MAX_ELEN, "XOR: 0^0=0");
        op(0,0, NOT, MAX_ELEN, "NOT: ~0=all-ones");
        op(3,3, AND, MAX_ELEN, "AND: x&x=x");
        op(3,3, OR,  MAX_ELEN, "OR:  x|x=x");
        op(3,3, XOR, MAX_ELEN, "XOR: x^x=0");
        op(8,9, OR,  MAX_ELEN, "OR:  F0F0|0F0F=FFFF");
        op(8,9, AND, MAX_ELEN, "AND: F0F0&0F0F=0000");
        op(8,9, XOR, MAX_ELEN, "XOR: F0F0^0F0F=FFFF");
        op(8,0, NOT, MAX_ELEN, "NOT: ~F0F0=0F0F");
        // Logical ops are elen-agnostic ? same result at all elen
        for(i=0;i<=MAX_ELEN;i=i+1) begin
            op(1,2, OR,  i, $sformatf("OR  elen=%0d (elen-agnostic)",i));
            op(1,2, AND, i, $sformatf("AND elen=%0d (elen-agnostic)",i));
            op(1,2, XOR, i, $sformatf("XOR elen=%0d (elen-agnostic)",i));
            op(1,0, NOT, i, $sformatf("NOT elen=%0d (elen-agnostic)",i));
        end
        suite_footer();

        // ============================================================
        suite_header("SUITE 2: Arithmetic ? Per-Lane (elen <= LANE_MAX_ELEN)");
        // ============================================================
        op(1,2, ADD, LANE_MAX_ELEN, "ADD: AAAA+5555=FFFF");
        op(2,1, ADD, LANE_MAX_ELEN, "ADD: 5555+AAAA=FFFF commutative");
        op(1,2, SUB, LANE_MAX_ELEN, "SUB: AAAA-5555");
        op(2,1, SUB, LANE_MAX_ELEN, "SUB: 5555-AAAA underflow");
        op(5,4, ADD, LANE_MAX_ELEN, "ADD: all-ones+1 overflow");
        op(4,5, SUB, LANE_MAX_ELEN, "SUB: 1-all-ones underflow");
        op(5,5, SUB, LANE_MAX_ELEN, "SUB: x-x=0");
        op(5,0, ADD, LANE_MAX_ELEN, "ADD: x+0=x");
        op(0,5, ADD, LANE_MAX_ELEN, "ADD: 0+x=x");
        op(5,0, SUB, LANE_MAX_ELEN, "SUB: x-0=x");
        op(0,0, ADD, LANE_MAX_ELEN, "ADD: 0+0=0");
        op(0,0, SUB, LANE_MAX_ELEN, "SUB: 0-0=0");
        op(6,7, ADD, LANE_MAX_ELEN, "ADD: DEAD+CAFE");
        op(6,7, SUB, LANE_MAX_ELEN, "SUB: DEAD-CAFE");
        op(7,6, SUB, LANE_MAX_ELEN, "SUB: CAFE-DEAD");
        op(10,11,ADD,LANE_MAX_ELEN, "ADD: sign_bit+max_pos");
        op(11,4, ADD,LANE_MAX_ELEN, "ADD: max_pos+1=sign_bit");
        op(10,4, SUB,LANE_MAX_ELEN, "SUB: sign_bit-1=max_pos");
        op(3,3,  ADD,LANE_MAX_ELEN, "ADD: all-ones+all-ones");
        op(0,3,  SUB,LANE_MAX_ELEN, "SUB: 0-all-ones=1");
        // All intra-lane elen values
        for(i=0;i<=LANE_MAX_ELEN;i=i+1) begin
            op(5,4, ADD, i, $sformatf("ADD FFFF+0001 overflow elen=%0d",i));
            op(0,4, SUB, i, $sformatf("SUB 0000-0001 underflow elen=%0d",i));
            op(6,7, ADD, i, $sformatf("ADD DEAD+CAFE elen=%0d",i));
            op(6,7, SUB, i, $sformatf("SUB DEAD-CAFE elen=%0d",i));
            op(1,2, ADD, i, $sformatf("ADD AAAA+5555 elen=%0d",i));
            op(2,1, SUB, i, $sformatf("SUB 5555-AAAA elen=%0d",i));
        end
        suite_footer();

        // ============================================================
        suite_header("SUITE 3: Cross-Lane Carry Chaining (elen > LANE_MAX_ELEN)");
        // ============================================================
        op(5,4, ADD, 3, "ADD FFFF+0001 elen=3: carry ripples 2 lanes");
        op(5,4, ADD, 4, "ADD FFFF+0001 elen=4: carry ripples 4 lanes");
        op(5,4, ADD, 5, "ADD FFFF+0001 elen=5: 512-bit single element");
        op(0,4, SUB, 3, "SUB 0-1 elen=3: borrow ripples 2 lanes");
        op(0,4, SUB, 4, "SUB 0-1 elen=4: borrow ripples 4 lanes");
        op(0,4, SUB, 5, "SUB 0-1 elen=5: borrow full 512-bit");
        // Verify isolation when elen <= LANE_MAX_ELEN
        op(5,4, ADD, LANE_MAX_ELEN, "ADD no-cross: independent lane overflow");
        // Mixed patterns at cross-lane
        op(6,7, ADD, 3, "ADD DEAD+CAFE elen=3");
        op(6,7, ADD, 4, "ADD DEAD+CAFE elen=4");
        op(6,7, ADD, 5, "ADD DEAD+CAFE elen=5");
        op(6,7, SUB, 3, "SUB DEAD-CAFE elen=3");
        op(6,7, SUB, 4, "SUB DEAD-CAFE elen=4");
        op(6,7, SUB, 5, "SUB DEAD-CAFE elen=5");
        op(7,6, SUB, 5, "SUB CAFE-DEAD elen=5");
        // Identities at cross-lane
        op(5,5, SUB, 5, "SUB x-x=0 elen=5");
        op(6,6, SUB, 4, "SUB x-x=0 elen=4");
        op(6,6, SUB, 3, "SUB x-x=0 elen=3");
        op(5,0, ADD, 5, "ADD x+0=x elen=5");
        op(6,0, ADD, 4, "ADD x+0=x elen=4");
        op(0,0, ADD, 5, "ADD 0+0=0 elen=5");
        op(0,0, SUB, 5, "SUB 0-0=0 elen=5");
        suite_footer();

        // ============================================================
        suite_header("SUITE 4: Full Register File Read-Back");
        // ============================================================
        for(i=0;i<REG_COUNT;i=i+1)
            op(i,0, OR, MAX_ELEN, $sformatf("readback reg[%0d]",i));
        suite_footer();

        // ============================================================
        suite_header("SUITE 5: Boundary and Edge Values");
        // ============================================================
        op(0,0, ADD, MAX_ELEN, "ADD: 0+0=0 full width");
        op(0,0, SUB, MAX_ELEN, "SUB: 0-0=0 full width");
        op(3,0, SUB, LANE_MAX_ELEN, "SUB: all-ones-0=all-ones");
        op(0,3, SUB, LANE_MAX_ELEN, "SUB: 0-all-ones=1");
        op(3,3, ADD, LANE_MAX_ELEN, "ADD: all-ones+all-ones");
        op(4,4, ADD, LANE_MAX_ELEN, "ADD: 0001+0001=0002");
        op(4,4, SUB, LANE_MAX_ELEN, "SUB: 0001-0001=0");
        op(11,4, ADD, LANE_MAX_ELEN, "ADD: 7FFF+1=8000 sign overflow");
        op(10,4, SUB, LANE_MAX_ELEN, "SUB: 8000-1=7FFF");
        op(14,15, ADD, 0, "ADD: alternating 16-bit elen=0");
        op(14,15, ADD, 1, "ADD: alternating 16-bit elen=1");
        op(14,15, OR,  MAX_ELEN, "OR:  alternating|inverse=FFFF");
        op(14,15, AND, MAX_ELEN, "AND: alternating&inverse=0000");
        op(12,13, OR,  MAX_ELEN, "OR:  upper|lower half=FFFF");
        op(12,13, AND, MAX_ELEN, "AND: upper&lower half=0000");
        op(12,13, ADD, LANE_MAX_ELEN, "ADD: upper_half+lower_half");
        op(12,13, ADD, 5, "ADD: upper_half+lower_half elen=5");
        suite_footer();

        // ============================================================
        suite_header("SUITE 6: Same-Source Operations");
        // ============================================================
        op(1,1, ADD, LANE_MAX_ELEN, "ADD: reg1+reg1");
        op(1,1, SUB, LANE_MAX_ELEN, "SUB: reg1-reg1=0");
        op(1,1, OR,  MAX_ELEN,      "OR:  reg1|reg1=reg1");
        op(1,1, AND, MAX_ELEN,      "AND: reg1&reg1=reg1");
        op(1,1, XOR, MAX_ELEN,      "XOR: reg1^reg1=0");
        op(5,5, ADD, LANE_MAX_ELEN, "ADD: all-ones+all-ones");
        op(5,5, SUB, LANE_MAX_ELEN, "SUB: all-ones-all-ones=0");
        op(5,5, ADD, 5,             "ADD: all-ones+all-ones elen=5");
        op(5,5, SUB, 5,             "SUB: all-ones-all-ones=0 elen=5");
        op(6,6, ADD, LANE_MAX_ELEN, "ADD: DEAD+DEAD");
        op(6,6, SUB, LANE_MAX_ELEN, "SUB: DEAD-DEAD=0");
        for(i=0;i<8;i=i+1)
            op(i,i, XOR, MAX_ELEN, $sformatf("XOR: reg[%0d]^reg[%0d]=0",i,i));
        for(i=0;i<8;i=i+1)
            op(i,i, SUB, LANE_MAX_ELEN, $sformatf("SUB: reg[%0d]-reg[%0d]=0",i,i));
        suite_footer();

        // ============================================================
        suite_header("SUITE 7: Back-to-Back Instructions");
        // ============================================================
        for(i=0;i<20;i=i+1) begin
            op(i%REG_COUNT, (i+1)%REG_COUNT, ADD, LANE_MAX_ELEN,
                $sformatf("B2B ADD #%02d reg[%0d]+reg[%0d]",i,i%REG_COUNT,(i+1)%REG_COUNT));
        end
        for(i=0;i<20;i=i+1) begin
            op(i%REG_COUNT, (i+1)%REG_COUNT, SUB, LANE_MAX_ELEN,
                $sformatf("B2B SUB #%02d reg[%0d]-reg[%0d]",i,i%REG_COUNT,(i+1)%REG_COUNT));
        end
        for(i=0;i<20;i=i+1) begin
            op(i%REG_COUNT, (i+1)%REG_COUNT, XOR, MAX_ELEN,
                $sformatf("B2B XOR #%02d",i));
        end
        // Mixed ops back-to-back
        op(1,2,  ADD, LANE_MAX_ELEN, "B2B MIX #01 ADD");
        op(2,3,  SUB, LANE_MAX_ELEN, "B2B MIX #02 SUB");
        op(3,4,  OR,  MAX_ELEN,      "B2B MIX #03 OR");
        op(4,5,  AND, MAX_ELEN,      "B2B MIX #04 AND");
        op(5,6,  XOR, MAX_ELEN,      "B2B MIX #05 XOR");
        op(6,0,  NOT, MAX_ELEN,      "B2B MIX #06 NOT");
        op(7,8,  ADD, 3,             "B2B MIX #07 ADD cross-lane");
        op(8,9,  SUB, 4,             "B2B MIX #08 SUB cross-lane");
        op(9,10, ADD, 5,             "B2B MIX #09 ADD full-width");
        op(10,11,SUB, 5,             "B2B MIX #10 SUB full-width");
        op(11,12,OR,  MAX_ELEN,      "B2B MIX #11 OR");
        op(12,13,AND, MAX_ELEN,      "B2B MIX #12 AND");
        op(13,14,XOR, MAX_ELEN,      "B2B MIX #13 XOR");
        op(14,0, NOT, MAX_ELEN,      "B2B MIX #14 NOT");
        op(15,1, ADD, LANE_MAX_ELEN, "B2B MIX #15 ADD");
        suite_footer();

        // ============================================================
        suite_header("SUITE 8: All Opcodes x All ELEN ? Exhaustive Sweep");
        // ============================================================
        for(i=0;i<=MAX_ELEN;i=i+1) begin
            op(6,7, ADD, i, $sformatf("SWEEP ADD DEAD,CAFE elen=%0d",i));
            op(6,7, SUB, i, $sformatf("SWEEP SUB DEAD,CAFE elen=%0d",i));
            op(7,6, SUB, i, $sformatf("SWEEP SUB CAFE,DEAD elen=%0d",i));
            op(1,2, OR,  i, $sformatf("SWEEP OR  AAAA,5555 elen=%0d",i));
            op(1,2, AND, i, $sformatf("SWEEP AND AAAA,5555 elen=%0d",i));
            op(1,2, XOR, i, $sformatf("SWEEP XOR AAAA,5555 elen=%0d",i));
            op(1,0, NOT, i, $sformatf("SWEEP NOT AAAA      elen=%0d",i));
            op(5,4, ADD, i, $sformatf("SWEEP ADD FFFF,0001 elen=%0d",i));
            op(0,4, SUB, i, $sformatf("SWEEP SUB 0000,0001 elen=%0d",i));
            op(8,9, OR,  i, $sformatf("SWEEP OR  F0F0,0F0F elen=%0d",i));
            op(8,9, AND, i, $sformatf("SWEEP AND F0F0,0F0F elen=%0d",i));
            op(8,9, XOR, i, $sformatf("SWEEP XOR F0F0,0F0F elen=%0d",i));
            op(8,0, NOT, i, $sformatf("SWEEP NOT F0F0      elen=%0d",i));
        end
        suite_footer();

        // ============================================================
        suite_header("SUITE 9: Write Enable Gating");
        // ============================================================
        load_uniform(20, 64'hC0FFEE00C0FFEE00);
        @(negedge clk);
        write_addr=20; write_data={WIDTH{1'b1}}; write_en=0; instr_valid=0;
        repeat(3) @(negedge clk);
        op(20,0, OR, MAX_ELEN, "write_en=0: reg[20] unchanged");
        load_uniform(20, 64'hBEEFBEEFBEEFBEEF);
        op(20,0, OR, MAX_ELEN, "write_en=1: reg[20] updated");
        load_uniform(20, 64'h1234567812345678);
        op(20,0, OR, MAX_ELEN, "write_en=1: reg[20] updated again");
        suite_footer();


        // ============================================================
        suite_header("SUITE 10: Simultaneous Read/Write ? Same Address Hazard");
        // ============================================================
        // BRAM always @(posedge clk) does write and read with pre-clock
        // mem state ? read gets OLD value (read-before-write behavior).

        load_uniform(21, 64'hAAAAAAAAAAAAAAAA);
        begin : hazard_src1
            reg [WIDTH-1:0] ov, nv, got;
            ov = shadow[21];
            nv = {LANE_COUNT{64'hBBBBBBBBBBBBBBBB}};
            @(negedge clk);
            write_addr=21; write_data=nv; write_en=1;
            src1=21; src2=0; opcode=OR; elen=MAX_ELEN; instr_valid=1;
            @(negedge clk); write_en=0; instr_valid=0;
            @(posedge clk); @(posedge clk); #1;
            got = result;
            if (got===ov || got===nv) begin
                pass=pass+1; suite_pass=suite_pass+1;
                $display("[PASS] Hazard src1: simultaneous RW reg[21] ? got %s value",
                    (got===ov)?"OLD (read-before-write)":"NEW (write-first)");
            end else begin
                fail=fail+1; suite_fail=suite_fail+1;
                $display("[FAIL] Hazard src1: unexpected result");
                $display("  Old=0x%0128h New=0x%0128h Got=0x%0128h", ov, nv, got);
            end
            shadow[21] = nv;
        end
        op(21, 0, OR, MAX_ELEN, "Hazard follow-up: write landed, reg[21]=BBBB");

        load_uniform(22, 64'hCCCCCCCCCCCCCCCC);
        begin : hazard_src2
            reg [WIDTH-1:0] ov, nv, got;
            ov = shadow[22];
            nv = {LANE_COUNT{64'hDDDDDDDDDDDDDDDD}};
            @(negedge clk);
            write_addr=22; write_data=nv; write_en=1;
            src1=0; src2=22; opcode=OR; elen=MAX_ELEN; instr_valid=1;
            @(negedge clk); write_en=0; instr_valid=0;
            @(posedge clk); @(posedge clk); #1;
            got = result;
            if (got===ov || got===nv) begin
                pass=pass+1; suite_pass=suite_pass+1;
                $display("[PASS] Hazard src2: simultaneous RW reg[22] ? got %s value",
                    (got===ov)?"OLD (read-before-write)":"NEW (write-first)");
            end else begin
                fail=fail+1; suite_fail=suite_fail+1;
                $display("[FAIL] Hazard src2: unexpected result");
                $display("  Old=0x%0128h New=0x%0128h Got=0x%0128h", ov, nv, got);
            end
            shadow[22] = nv;
        end
        op(22, 0, OR, MAX_ELEN, "Hazard src2 follow-up: write landed, reg[22]=DDDD");

        // No-hazard: write to different addr than read ? both must work
        load_uniform(23, 64'hEEEEEEEEEEEEEEEE);
        load_uniform(24, 64'h1111111111111111);
        begin : no_hazard
            reg [WIDTH-1:0] nv;
            nv = {LANE_COUNT{64'h2222222222222222}};
            @(negedge clk);
            write_addr=24; write_data=nv; write_en=1;
            src1=23; src2=0; opcode=OR; elen=MAX_ELEN; instr_valid=1;
            @(negedge clk); write_en=0; instr_valid=0;
            @(posedge clk); @(posedge clk); #1;
            shadow[24] = nv;
        end
        op(23, 0, OR, MAX_ELEN, "No-hazard: read reg[23] while writing reg[24]");
        op(24, 0, OR, MAX_ELEN, "No-hazard: reg[24] has new value");
        suite_footer();

        // ============================================================
        suite_header("SUITE 11: instr_valid Gating");
        // ============================================================
        op(1,2, OR, MAX_ELEN, "establish known result");
        held = result;
        @(negedge clk); src1=16; src2=17; opcode=ADD; elen=LANE_MAX_ELEN; instr_valid=0;
        repeat(8) @(posedge clk); #1;
        if(result===held) begin
            pass=pass+1; suite_pass=suite_pass+1;
            $display("[PASS] valid=0 for 8 cycles: result stable");
        end else begin
            fail=fail+1; suite_fail=suite_fail+1;
            $display("[FAIL] valid=0 for 8 cycles: result changed");
        end
        repeat(4) @(posedge clk); #1;
        if(result===held) begin
            pass=pass+1; suite_pass=suite_pass+1;
            $display("[PASS] valid=0 for 12 cycles: result still stable");
        end else begin
            fail=fail+1; suite_fail=suite_fail+1;
            $display("[FAIL] valid=0 for 12 cycles: result changed");
        end
        op(16,17, ADD, LANE_MAX_ELEN, "valid=1 after idle: executes correctly");
        op(1,2,   OR,  MAX_ELEN,      "valid=1 second instr after idle: correct");
        suite_footer();

        // ============================================================
        suite_header("SUITE 12: Reset Behavior");
        // ============================================================
        op(6,7, ADD, LANE_MAX_ELEN, "pre-reset ADD baseline");
        @(negedge clk); rst=1;
        repeat(3) @(posedge clk);
        @(negedge clk); rst=0; repeat(2) @(posedge clk);
        op(6,7, AND, MAX_ELEN,      "post-reset AND");
        op(6,7, XOR, MAX_ELEN,      "post-reset XOR");
        op(6,7, ADD, LANE_MAX_ELEN, "post-reset ADD per-lane");
        op(1,2, OR,  MAX_ELEN,      "post-reset OR");
        op(5,4, ADD, LANE_MAX_ELEN, "post-reset ADD overflow");
        op(5,4, ADD, 5,             "post-reset ADD elen=5 cross-lane");
        op(0,4, SUB, 5,             "post-reset SUB elen=5 cross-lane");
        // Second reset
        @(negedge clk); rst=1; repeat(2) @(posedge clk);
        @(negedge clk); rst=0; repeat(2) @(posedge clk);
        op(8,9,  ADD, LANE_MAX_ELEN, "post-2nd-reset ADD");
        op(8,9,  OR,  MAX_ELEN,      "post-2nd-reset OR");
        op(5,4,  ADD, 5,             "post-2nd-reset ADD elen=5");
        suite_footer();

        // ============================================================
        suite_header("SUITE 13: Random Instructions ? 200 Tests");
        // ============================================================
        for(i=16;i<REG_COUNT;i=i+1) load_rand(i);
        for(k=0;k<200;k=k+1) begin
            ra      = $unsigned($random) % REG_COUNT;
            rb      = $unsigned($random) % REG_COUNT;
            rand_op = $unsigned($random) % 6;
            rand_el = $unsigned($random) % (MAX_ELEN+1);
            op(ra, rb, rand_op, rand_el,
               $sformatf("RAND #%03d %s reg[%0d],reg[%0d] elen=%0d", k,
               (rand_op==ADD)?"ADD":(rand_op==SUB)?"SUB":(rand_op==OR)?"OR":
               (rand_op==AND)?"AND":(rand_op==NOT)?"NOT":"XOR",
               ra,rb,rand_el));
        end
        suite_footer();

        // ============================================================
        $display("\n================================================================================");
        $display("  FINAL SUMMARY");
        $display("================================================================================");
        $display("  PASSED : %0d", pass);
        $display("  FAILED : %0d", fail);
        $display("  TOTAL  : %0d", pass+fail);
        $display("  RATE   : %.1f%%", (pass*100.0)/(pass+fail));
        $display("================================================================================");
        if(fail==0) $display("  *** ALL TESTS PASSED ***");
        else        $display("  *** %0d TESTS FAILED ***", fail);
        $display("================================================================================\n");
        $finish;
    end

    initial begin $dumpfile("executeStage_tb.vcd"); $dumpvars(0,executeStage_tb); end

endmodule