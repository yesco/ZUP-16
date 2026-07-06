// Editing: Only change lines if really needed, any other changes ask
`timescale 1ns/1ps

module mini8_tb;
    reg clk;
    reg rst_n;

    // Instantiate your inline CPU core
    mini8 cpu (
        .clk(clk),
        .rst_n(rst_n)
    );

    // 1. Generate clock toggles (50MHz simulation)
    always #10 clk = ~clk;

    initial begin
        // Print formatting header for your terminal screen
        $display("----------------------------------");
        $display(" TIME  | PC | Z C N V TOS NOS N2");
        $display("----------------------------------");
        
        // Target loop hook: Prints data automatically whenever variables change
        $monitor("%6d | %02h | %b %b %b %b  %02h %02h %02h ",
                 $time, cpu.pc, cpu.z, cpu.c, cpu.n, cpu.v,
		 cpu.acc, cpu.acc, cpu.acc);

        // 2. Perform the safe Hardware Reset
        clk = 0;
        rst_n = 0;
        #25;
        rst_n = 1; // Release reset to start execution loop

        // 3. Run the loop long enough to watch the JZ operations take place
        #300; 
        $display("--------------------------------------------");
        $finish; // Safely stop simulation execution
    end
endmodule
