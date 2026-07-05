module cpu_top(
    input  wire       clk,        // Onboard 27MHz clock
    input  wire       rst_n,      // Active-low user reset button
    output reg  [4:0] pins_out,   // Lower 5 bits to header pins
    output wire [2:0] leds_out    // Higher 3 bits to onboard LEDs
);

    // Core Data Registers
    reg [7:0] acc;
    reg [7:0] pc; // Expanded to full 8-bit to handle 4 clean 2-bit slices
    
    integer i;

    // Direct physical routing connections (LEDs are Active-Low)
    assign leds_out = ~acc[7:5];
    always @(*) pins_out = acc[4:0];

    // Fast Fabric Mini-ROM (256 Bytes x 8-bit instructions)
    reg [7:0] rom [0:255];

    initial begin
        // Example Program running in the prefix encoding layout:
        rom[8'h00] = 8'b0_0000001; // PC=0: Prefix 0  -> ADD 1   (ACC = ACC + 1)
        rom[8'h01] = 8'b10_001010; // PC=1: Prefix 10 -> XOR 10  (ACC = ACC ^ 6'd10)
        
        // --- HARDWARE HALT TRAP (Using New JZ Instruction) ---
        // If ACC becomes 0 after the XOR, it jumps directly to PC=3 forever.
        rom[8'h02] = 8'b11_000011; // PC=2: Prefix 11 -> JZ 3    (Jump to 3 if ACC == 0)
        rom[8'h03] = 8'b11_000011; // PC=3: Prefix 11 -> JZ 3    (Self-trapping hardware halt)

        // Zero out remaining 256-byte ROM space cleanly
        for (i = 4; i < 256; i = i + 1) begin
            rom[i] = 8'b0_0000000;
        end
    end

    // Variable-Length Prefix Operand Decoders
    wire [7:0] instr   = rom[pc];
    wire [6:0] op_7bit = instr[6:0]; // 7-bit operand used by Prefix 0 (ADD)
    wire [5:0] op_6bit = instr[5:0]; // 6-bit operand used by Prefix 10/11 (XOR/JZ)

    // --- STRUCTURAL 2-BIT PC STRIDE LOGIC ---
    // Two global control lines broadcast to all slices
    // Command Encoding: 00=-1, 01=0, 10=+1, 11=+2
    wire [1:0] ctrl;
    
    assign ctrl = (instr[7:6] == 2'b11 && acc == 8'h00) ? 
                  ((op_6bit == pc[5:0]) ? 2'b01 : 2'b11) : // 01=Hold (Halt on self), 11=+2 (Jump offset)
                  2'b10; // 10=+1 Standard Forward Stride

    // Intermediate tracking wires for the 4 parallel slices
    wire [1:0] next_pc3, next_pc2, next_pc1, next_pc0;

    // Instantiate the 4 identical lookup table slices directly into the routing grid
    assign next_pc0 = luts_pair(ctrl, pc[1:0]);
    assign next_pc1 = luts_pair(ctrl, pc[3:2]);
    assign next_pc2 = luts_pair(ctrl, pc[5:4]);
    assign next_pc3 = luts_pair(ctrl, pc[7:6]);

    // Reusable 4-input mapping function (The 16-case truth table)
    function [1:0] luts_pair(input [1:0] c, input [1:0] p);
        case ({c, p})
            // Command 00: Decrement (-1)
            4'b00_00: luts_pair = 2'b11; 4'b00_01: luts_pair = 2'b00;
            4'b00_10: luts_pair = 2'b01; 4'b00_11: luts_pair = 2'b10;
            // Command 01: Hold (0)
            4'b01_00: luts_pair = 2'b00; 4'b01_01: luts_pair = 2'b01;
            4'b01_10: luts_pair = 2'b10; 4'b01_11: luts_pair = 2'b11;
            // Command 10: Increment (+1)
            4'b10_00: luts_pair = 2'b01; 4'b10_01: luts_pair = 2'b10;
            4'b10_10: luts_pair = 2'b11; 4'b10_11: luts_pair = 2'b00;
            // Command 11: Stride (+2 / Jump Bypass)
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
            
            // Latch structural slice transformations with zero ALU carry strings
            pc <= {next_pc3, next_pc2, next_pc1, next_pc0};

            // Extensible casez prefix matching block for Data math
            casez (instr[7:6])
                2'b0?: begin // --- PREFIX 0: ADD ---
                    acc <= acc + op_7bit;
                end
                
                2'b10: begin // --- PREFIX 10: XOR ---
                    acc <= acc ^ op_6bit; 
                end
                
                default: begin
                    // Prefix 11 (JZ) handles its state changes purely via the 'ctrl' wire above
                end
            endcase
        end
    end

endmodule
