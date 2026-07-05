module cpu_top(
    input  wire       clk,        // Onboard 27MHz clock
    input  wire       rst_n,      // Active-low user reset button
    output reg  [4:0] pins_out,   // Lower 5 bits to header pins
    output wire [2:0] leds_out    // Higher 3 bits to onboard LEDs
);

    // Core Data Registers
    reg [7:0] acc;
    reg [7:0] pc;
    
    integer i;

    // Direct physical routing connections (LEDs are Active-Low)
    assign leds_out = ~acc[7:5];
    always @(*) pins_out = acc[4:0];

    // Fast Fabric Mini-ROM (256 Bytes x 8-bit instructions)
    reg [7:0] rom [0:255];

    initial begin
        // Example Program running in the Jump-to-Zero layout:
        rom[8'h00] = 8'b0_0000001; // PC=0: Prefix 0  -> ADD 1   (ACC = ACC + 1)
        rom[8'h01] = 8'b10_001010; // PC=1: Prefix 10 -> XOR 10  (ACC = ACC ^ 6'd10)
        
        // --- JUMP TO ZERO TRAP ---
        rom[8'h02] = 8'b11_000000; // PC=2: If ACC == 0, jump to 0. Else PC = 3.
        rom[8'h03] = 8'b11_000000; // PC=3: Fallback trap

        // Zero out remaining 256-byte ROM space cleanly
        for (i = 4; i < 256; i = i + 1) begin
            rom[i] = 8'b0_0000000;
        end
    end

    // Variable-Length Prefix Operand Decoders
    wire [7:0] instr   = rom[pc];
    wire [6:0] op_7bit = instr[6:0]; 
    wire [5:0] op_6bit = instr[5:0]; 

    // --- STRUCTURAL 2-BIT PC STRIDE LOGIC ---
    wire [1:0] ctrl;
    
    wire jump_to_zero_taken = (instr[7:6] == 2'b11 && acc == 8'h00);
    assign ctrl = jump_to_zero_taken ? 2'b01 : 2'b10; // 10=+1 Standard Forward Stride

    // Intermediate tracking wires for the 4 parallel slices
    wire [1:0] next_pc3, next_pc2, next_pc1, next_pc0;

    assign next_pc0 = luts_pair(ctrl, pc[1:0]);
    assign next_pc1 = luts_pair(ctrl, pc[3:2]);
    assign next_pc2 = luts_pair(ctrl, pc[5:4]);
    assign next_pc3 = luts_pair(ctrl, pc[7:6]);

    function [1:0] luts_pair(input [1:0] c, input [1:0] p);
        case ({c, p})
            4'b00_00: luts_pair = 2'b11; 4'b00_01: luts_pair = 2'b00;
            4'b00_10: luts_pair = 2'b01; 4'b00_11: luts_pair = 2'b10;
            
            4'b01_00: luts_pair = 2'b00; 4'b01_01: luts_pair = 2'b01;
            4'b01_10: luts_pair = 2'b10; 4'b01_11: luts_pair = 2'b11;
            
            4'b10_00: luts_pair = 2'b01; 4'b10_01: luts_pair = 2'b10;
            4'b10_10: luts_pair = 2'b11; 4'b10_11: luts_pair = 2'b00;
            
            4'b11_00: luts_pair = 2'b10; 4'b11_01: luts_pair = 2'b11;
            4'b11_10: luts_pair = 2'b00; 4'b11_11: luts_pair = 2'b01;
        endcase
    endfunction

    // Single-cycle Synchronous Register Update Block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc <= 8'h00;
            pc  <= 8'h00;
        end else begin
            if (jump_to_zero_taken) begin
                pc <= 8'h00; 
            end else begin
                pc <= {next_pc3, next_pc2, next_pc1, next_pc0};
            end

            casez (instr[7:6])
                2'b0?: begin 
                    acc <= acc + op_7bit;
                end
                2'b10: begin 
                    acc <= acc ^ op_6bit; 
                end
                default: begin
                end
            endcase
        end
    end

endmodule
