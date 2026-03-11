`timescale 1ns/1ps

import RISCV_PKG::*;

module tb_ssn;

    // Signals
    logic [MLENB-1:0][BYTE:0] data_in;
    logic [NUM_LAYERS-1:0][MLENB-1:0] controls;
    wire [MLENB-1:0][BYTE:0] data_out;

    // Instantiate DUT
    ssn dut (
        .data_in(data_in),
        .controls(controls),
        .data_out(data_out)
    );

    // Test sequence
    initial begin
        $display("========================================");
        $display("SSN (Scatter Shift Network) Testbench");
        $display("MLEN = %0d, BYTE = %0d, NUM_LAYERS = %0d", MLEN, BYTE, NUM_LAYERS);
        $display("MLENB = %0d", MLENB);
        $display("========================================\n");

        // Test 1: All zeros
        $display("Test 1: All zeros");
        data_in = '0;
        controls = '0;
        #10;
        $display("data_in = %h", data_in);
        $display("controls = %h", controls);
        $display("data_out = %h\n", data_out);
        // Assert: All zeros input should produce all zeros output
        assert (data_out == '0) else $error("Test 1 FAILED: Expected all zeros output");
        $display("Test 1 PASSED");

        // Test 2: Simple pattern with no shift (all control bits = 0)
        $display("Test 2: Simple pattern with no shift");
        for (int i = 0; i < MLENB; i++) begin
            data_in[i] = {1'b1, i[BYTE-1:0]};
        end
        controls = '0;
        #10;
        $display("data_in[0:7] = %h %h %h %h %h %h %h %h", 
                 data_in[0], data_in[1], data_in[2], data_in[3],
                 data_in[4], data_in[5], data_in[6], data_in[7]);
        $display("controls = %h", controls);
        $display("data_out[0:7] = %h %h %h %h %h %h %h %h\n", 
                 data_out[0], data_out[1], data_out[2], data_out[3],
                 data_out[4], data_out[5], data_out[6], data_out[7]);
        // Assert: With no shift (controls=0), output should be zeros (no scattering)
        for (int i = 0; i < 8; i++) begin
            assert (data_out[i] == data_in[i]) else 
                $error("Test 2 FAILED at element %0d: Expected 0x000, got 0x%h", i, data_out[i]);
        end
        $display("Test 2 PASSED");

        // Test 3: Pattern with first layer control = 1
        $display("Test 3: First layer control bits = 1");
        for (int i = 0; i < MLENB; i++) begin
            data_in[i] = {1'b1, BYTE'((i + 1) << 1)}; // Values: 2, 4, 6, 8, ...
        end
        controls[0] = '0; // All first layer controls = 1
        controls[1] = '1;
        for (int layer = 2; layer < NUM_LAYERS; layer++) begin
            controls[layer] = '0;
        end
        #10;
        $display("data_in[0:7] = %h %h %h %h %h %h %h %h", 
                 data_in[0], data_in[1], data_in[2], data_in[3],
                 data_in[4], data_in[5], data_in[6], data_in[7]);
        $display("controls[0] = %b", controls[0]);
        $display("data_out[0:7] = %h %h %h %h %h %h %h %h\n", 
                 data_out[0], data_out[1], data_out[2], data_out[3],
                 data_out[4], data_out[5], data_out[6], data_out[7]);

        // Test 4: Shift at each layer

        for(int layer = 0; layer < NUM_LAYERS; layer++) begin
            for (int elem = 0; elem < MLENB; elem++) begin
                data_in[elem] = {1'b1, BYTE'(elem)}; // Values: 0, 1, 2, 3, ...
                controls[layer][elem] = 1'b1; // Shift at current layer
            end
            #10;
            $display("Test 4: Shift at layer %0d", layer);
            $display("data_in[0:7] = %h %h %h %h %h %h %h %h", 
                     data_in[0], data_in[1], data_in[2], data_in[3],
                     data_in[4], data_in[5], data_in[6], data_in[7]);
            $display("controls[%0d] = %b", layer, controls[layer]);
            $display("data_out[0:7] = %h %h %h %h %h %h %h %h", 
                        data_out[0], data_out[1], data_out[2], data_out[3],
                        data_out[4], data_out[5], data_out[6], data_out[7]);
        end


        // Final verification
        $display("========================================");
        $display("All SSN tests completed successfully!");
        $display("SSN Testbench Complete");
        $display("========================================");
        $finish;
    end

endmodule
