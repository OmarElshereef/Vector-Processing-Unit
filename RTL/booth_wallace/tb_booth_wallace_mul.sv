 // Testbench
module tb_booth_wallace_multiplier;
    parameter WIDTH = 64;
    
    reg [WIDTH-1:0] a, b;
    wire [2*WIDTH-1:0] product;
    reg is_unsigned;
    
    booth_wallace_multiplier #(.WIDTH(WIDTH)) dut (
        .multiplicand(a),
        .multiplier(b),
        .is_unsigned(is_unsigned),
        .product(product)
    );
    
    integer i;
    integer count_signed = 0;
    integer count_unsigned = 0;
    reg [2*WIDTH-1:0] expected;
    
    initial begin
        // Test SIGNED multiplication
        $display("=== Testing %0d-bit SIGNED Booth-Wallace Multiplier ===", WIDTH);
        $display("Time\tA\tB\tProduct\tExpected\tMatch");
        is_unsigned = 1'b0;
        
        for (i = 0; i < 20; i = i + 1) begin
            a = $random;
            b = $random;
            expected = $signed(a) * $signed(b);
            #10;
            
            $display("%0t\t%0d\t%0d\t%0d\t%0d\t%s", 
                     $time, $signed(a), $signed(b), $signed(product), $signed(expected), 
                     ($signed(product) == $signed(expected)) ? "PASS" : "FAIL");

            count_signed = ($signed(product) == $signed(expected)) ? count_signed + 1 : count_signed;
        end
        
        $display("Passed %0d out of 20 signed tests.", count_signed);
        
        // Edge cases for signed
        a = 0; b = 0; #10;
        $display("0 * 0 = %0d (Expected: 0) %s", product, (product == 0) ? "PASS" : "FAIL");
        
        a = {WIDTH{1'b1}}; b = {WIDTH{1'b1}}; expected = $signed(a) * $signed(b); #10;
        $display("-1 * -1 = %0d (Expected: %0d) %s", $signed(product), $signed(expected), ($signed(product) == $signed(expected)) ? "PASS" : "FAIL");
        
        a = 1; b = {WIDTH{1'b1}}; expected = $signed(a) * $signed(b); #10;
        $display("1 * -1 = %0d (Expected: %0d) %s", $signed(product), $signed(expected), ($signed(product) == $signed(expected)) ? "PASS" : "FAIL");
        
        // Test UNSIGNED multiplication
        $display("\n=== Testing %0d-bit UNSIGNED Booth-Wallace Multiplier ===", WIDTH);
        $display("Time\tA\tB\tProduct\tExpected\tMatch");
        is_unsigned = 1'b1;
        
        for (i = 0; i < 20; i = i + 1) begin
            a = $random;
            b = $random;
            expected = a * b;
            #10;
            
            $display("%0t\t%0d\t%0d\t%0d\t%0d\t%s", 
                     $time, a, b, product, expected, 
                     (product == expected) ? "PASS" : "FAIL");

            count_unsigned = (product == expected) ? count_unsigned + 1 : count_unsigned;
        end
        
        $display("Passed %0d out of 20 unsigned tests.", count_unsigned);
        
        // Edge cases for unsigned
        a = 0; b = 0; #10;
        $display("0 * 0 = %0d (Expected: 0) %s", product, (product == 0) ? "PASS" : "FAIL");
        
        a = {WIDTH{1'b1}}; b = {WIDTH{1'b1}}; expected = a * b; #10;
        $display("%0d * %0d = %0d (Expected: %0d) %s", a, b, product, expected, (product == expected) ? "PASS" : "FAIL");
        
        a = 255; b = 255; expected = a * b; #10;
        $display("255 * 255 = %0d (Expected: %0d) %s", product, expected, (product == expected) ? "PASS" : "FAIL");
        
        $finish;
    end
endmodule
