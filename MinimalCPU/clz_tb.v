`timescale 1ns/1ps

module clz_tb;

    // Inputs to the module under test are declared as registers (reg)
    reg [15:0] test_input;
    
    // Outputs from the module under test are declared as wires
    wire [4:0] clz_result;

    // 1. Instantiate the Unit Under Test (UUT)
    clz uut (
        .in(test_input),
        .clz_out(clz_result)
    );

    // 2. The Simulation Loop (Acts like a main function)
    initial begin
        // Print a nice layout header to the console window
        $display("========================================");
        $display("   TESTING LOGARITHMIC CLZ MODULE       ");
        $display("========================================");
        $display("  HEX INPUT | BINARY INPUT     | CLZ OUT");
        $display("----------------------------------------");

        // Test Case 1: No leading zeros (MSB is 1)
        test_input = 16'h8000; #10;
        $display("  0x%h   | %b | %d", test_input, test_input, clz_result);

        // Test Case 2: One leading zero
        test_input = 16'h4000; #10;
        $display("  0x%h   | %b | %d", test_input, test_input, clz_result);

        // Test Case 3: Exactly four leading zeros
        test_input = 16'h0A00; #10;
        $display("  0x%h   | %b | %d", test_input, test_input, clz_result);

       // Test Case 4: A deep stack of leading zeros
        test_input = 16'h000F; #10;
        $display("  0x%h   | %b | %d", test_input, test_input, clz_result);

        // Test Case 5: The absolute edge case (Input is completely zero)
        test_input = 16'h0000; #10;
        $display("  0x%h   | %b | %d", test_input, test_input, clz_result);

        $display("----------------------------------------");
        $display(" Simulation Complete.");
        $finish; // Gracefully terminates the simulator
    end

endmodule
