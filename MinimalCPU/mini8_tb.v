// mini8_tb.v: A "terminaL' for mini8
//
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

    // --- NEW: Mnemonic Decoder Net (24 bits = 3 ASCII characters) ---
    reg [23:0] mnemonic;
    always @(*) begin
        case (cpu.op)
            3'b000: mnemonic = "ADD";
            3'b001: mnemonic = "ADC";
            3'b010: mnemonic = "SUB";
            3'b011: mnemonic = "JZ ";
            3'b100: mnemonic = "AND"; 
            3'b101: mnemonic = "OR ";
            3'b110: mnemonic = "XOR";
            3'b111: mnemonic = "INV";
            default: mnemonic = "???";
        endcase
    end

    initial begin
        // Print formatting header for your terminal screen
        // EDITED LINE: Expanded header space for the instruction argument
        $display("------------------------------------------");
        $display(" TIME  | PC | INSTR  | Z C N V TOS NOS N2");
        $display("------------------------------------------");
        
        // Target loop hook: Prints data automatically whenever variables change
        // EDITED LINE: Added %02h right after the string to capture the immediate operand
        $monitor("%6d | %02h | %s %02h | %b %b %b %b  %02h %02h %02h ",
                 $time, cpu.pc, mnemonic, cpu.reg2, cpu.z, cpu.c, cpu.n, cpu.v,
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
