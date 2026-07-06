// mini8_tb.v: A "terminaL' for mini8
//
// Editing: Only change lines if really needed, any other changes ask

`timescale 1ns/1ps

module mini8_tb;
    reg clk;
    reg rst_n;
    
    // --- Testbench ROM Memory Array ---
    reg [7:0] instruction_rom[0:255]; 
    wire [7:0] current_instruction = instruction_rom[cpu.pc];

    // Instantiate your inline CPU core
    mini8 cpu (
        .clk(clk),
        .rst_n(rst_n),
        .instruction(current_instruction)
    );

    // 1. Generate clock toggles (50MHz simulation)
    always #10 clk = ~clk;

    // --- Mnemonic Decoder Net ( up to 4 ASCII characters) ---
    reg [34:0] mnemonic;
    always @(*) begin
        if (cpu.instruction[7] == 1'b0) begin
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

    // --- Dynamic Argument String Formatter ---
    reg [23:0] arg_str;
    always @(*) begin
        if (current_instruction[7] == 1'b0) begin
            $sformat(arg_str, "%02h ", current_instruction[6:0]);
        end else begin
            arg_str = "   "; 
        end
    end

    initial begin
        // --- Load the program instructions into our Testbench ROM array ---
        instruction_rom[8'h00] = 8'b0_0000111;  // LIT 7
        instruction_rom[8'h01] = 8'b0_0000101;  // LIT 5
        instruction_rom[8'h02] = 8'b0_0000011;  // LIT 3
        instruction_rom[8'h03] = 8'b1_0001_000; // GROUP 1, ADD
        instruction_rom[8'h04] = 8'b1_0001_000; // GROUP 1, ADD
        instruction_rom[8'h05] = 8'b1_0001_111; // GROUP 1, DROP
        
        // EDITED LINE: Fixed the index bound to start at 6 so it skips your valid program code
        for (integer i = 6; i < 256; i = i + 1) begin
            instruction_rom[i] = 8'h00;
        end

        // Print formatting header for your terminal screen
        $display("------------------------------------------");
        $display(" TIME  | PC | INSTR  | Z C N V TOS NOS N2");
        $display("------------------------------------------");
        
        $monitor("%6d | %02h |%s%s| %b %b %b %b  %02h %02h %02h",
                 $time, cpu.pc, mnemonic, arg_str, cpu.z, cpu.c, cpu.n, cpu.v,
                 cpu.tos, cpu.nos, cpu.n2);

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
