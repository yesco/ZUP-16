module cpu_top(
    input  wire       clk,        // Onboard 27MHz clock
    input  wire       rst_n,      // Active-low user reset button
    output reg  [4:0] pins_out,   // Lower 5 bits to header pins
    output wire [2:0] leds_out    // Higher 3 bits to onboard LEDs
);

    // Core Data Blocks
    reg [7:0] acc;
    reg [6:0] pc;
    
    // Explicit integer loop tracking register for Yosys synthesis matching
    integer i;

    // Direct physical routing connections (LEDs are Active-Low)
    assign leds_out = ~acc[7:5];
    always @(*) pins_out = acc[4:0];

    // Fast Fabric Mini-ROM (128 Bytes x 8-bit instructions)
    reg [7:0] rom [0:127];

    initial begin
        // Example Program running in the prefix encoding layout:
        rom[0] = 8'b0_0000001; // PC=0: Prefix 0  -> ADD 1   (ACC = ACC + 1)
        rom[1] = 8'b10_001010; // PC=1: Prefix 10 -> XOR 10  (ACC = ACC ^ 6'd10)
        
        // --- HARDWARE HALT TRAP (Using New JZ Instruction) ---
        rom[2] = 8'b11_000011; // PC=2: Prefix 11 -> JZ 3    (Jump to 3 if ACC == 0)
        rom[3] = 8'b11_000011; // PC=3: Prefix 11 -> JZ 3    (Self-trapping hardware halt)

        // Zero out remaining 128-byte ROM space cleanly
        for (i = 4; i < 128; i = i + 1) begin
            rom[i] = 8'b0_0000000;
        end
    end

    // Variable-Length Prefix Operand Decoders
    wire [7:0] instr   = rom[pc];
    wire [6:0] op_7bit = instr[6:0]; // 7-bit operand used by Prefix 0 (ADD)
    wire [5:0] op_6bit = instr[5:0]; // 6-bit operand used by Prefix 10/11 (XOR/JZ)

    // Single-cycle Execution Block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc <= 8'h00;
            pc  <= 7'h00;
        end else begin
            
            // 1. Single default statement up front handles the counter circuit loop
            pc <= pc + 1'b1; 

            // 2. Extensible casez prefix matching block
            casez (instr[7:6])
                2'b0?: begin // --- PREFIX 0: ADD ---
                    acc <= acc + op_7bit;
                end
                
                2'b10: begin // --- PREFIX 10: XOR ---
                    acc <= acc ^ op_6bit; 
                end
                
                2'b11: begin // --- PREFIX 11: JZ (Jump if Zero) ---
                    if (acc == 8'h00) begin
                        pc <= {1'b0, op_6bit}; // Overrides default PC increment
                    end
                end
            endcase
        end
    end

endmodule
