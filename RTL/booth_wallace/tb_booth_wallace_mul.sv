// Testbench
module tb_booth_wallace_multiplier;
    parameter WIDTH = 8;
    
    reg signed [WIDTH-1:0] a, b;
    wire signed [2*WIDTH-1:0] product;
    
    booth_wallace_multiplier #(.WIDTH(WIDTH)) dut (
        .multiplicand(a),
        .multiplier(b),
        .product(product)
    );
    
    integer i;
     integer count = 0;
    reg signed [2*WIDTH-1:0] expected;
    
    initial begin
       
        $display("Testing %0d-bit Booth-Wallace Multiplier", WIDTH);
        $display("Time\tA\tB\tProduct\tExpected\tMatch");
        
        // Test cases (now allow negative numbers)
        for (i = 0; i < 20; i = i + 1) begin
            a = $random;
            b = $random;
            expected = $signed(a) * $signed(b);
            #10;
            
            $display("%0t\t%0d\t%0d\t%0d\t%0d\t%s", 
                     $time, a, b, product, expected, 
                     ($signed(product) == expected) ? "PASS" : "FAIL");

            count = (product == expected) ? count + 1 : count;
        end
        
        $display("Passed %0d out of 20 tests.", count);
        // Edge cases
        a = 0; b = 0; #10;
        $display("0 * 0 = %0d (Expected: 0) %s", product, (product == 0) ? "PASS" : "FAIL");
        
        a = {WIDTH{1'b1}}; b = {WIDTH{1'b1}}; expected = $signed(a) * $signed(b); #10;
        $display("ALL_ONES * ALL_ONES = %0d (Expected: %0d) %s", product, expected, ($signed(product) == expected) ? "PASS" : "FAIL");
        
        a = 1; b = {WIDTH{1'b1}}; expected = $signed(a) * $signed(b); #10;
        $display("1 * ALL_ONES = %0d (Expected: %0d) %s", product, expected, ($signed(product) == expected) ? "PASS" : "FAIL");
        
        $finish;
    end
endmodule
