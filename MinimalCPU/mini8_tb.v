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

    // --- Mnemonic Decoder Net ( up to 4 ASCII characters) ---
    reg [34:0] mnemonic;
    always @(*) begin
        if (cpu.is_lit) begin
            mnemonic = "LIT#";
        end else begin
            case (cpu.grp)
                4'b0001: begin // GRP_ALU
                    case (cpu.sub_op)
                        3'b000: mnemonic = "ADD ";
                        3'b001: mnemonic = "ADC ";
                        3'b010: mnemonic = "SUB ";
                        3'b011: mnemonic = "SBC ";
                        3'b100: mnemonic = "AND "; 
                        3'b101: mnemonic = "OR  ";
                        3'b110: mnemonic = "XOR ";
                        3'b111: mnemonic = "DROP";
                        default: mnemonic = "??? ";
                    endcase
                end
                4'b0010: mnemonic = "JZ  "; // GRP_JZ
                4'b0100: mnemonic = "stk "; // GRP_STACK
                default: mnemonic = "--- ";
            endcase
        end
    end

    // Capture dynamic argument field depending on the active instruction layout format
    wire [7:0] dynamic_arg = cpu.is_lit ? {1'b0, cpu.lit_data} : {5'b00000, cpu.sub_op};

    initial begin
        // Print formatting header for your terminal screen
        $display("------------------------------------------");
        $display(" TIME  | PC | INSTR | Z C N V TOS NOS N2");
        $display("------------------------------------------");
        
        if (cpu.is_lit) begin
          // Target loop hook: Prints data automatically whenever variables change
          $monitor("%6d | %02h | %s%02h | %b %b %b %b  %02h %02h",
                   $time, cpu.pc, mnemonic, dynamic_arg, cpu.z, cpu.c, cpu.n,
                   cpu.acc, cpu.nos, cpu.n2);
        end else begin
          // Target loop hook: Prints data automatically whenever variables change
          $monitor("%6d | %02h | %s   | %b %b %b %b  %02h %02h",
                   $time, cpu.pc, mnemonic, cpu.z, cpu.c, cpu.n,
                   cpu.acc, cpu.nos, cpu.n2);
	end
 

        // 2. Perform the safe Hardware Reset
        clk = 0;
        rst_n = 0;
        #25;
        rst_n = 1; // Release reset to start execution loop

        // 3. Run the loop long enough to watch operations take place
        #300; 
        $display("--------------------------------------------");
        $finish; // Safely stop simulation execution
    end
endmodule
