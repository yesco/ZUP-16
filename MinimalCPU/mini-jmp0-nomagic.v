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
        rom[8'h00] = 8'b0_0000001; // PC=0: ADD 1
        rom[8'h01] = 8'b10_001010; // PC=1: XOR 10
        rom[8'h02] = 8'b11_000000; // PC=2: JZ 0 (Jump to 0 if ACC == 0)
        rom[8'h03] = 8'b11_000000; // PC=3: Fallback trap

        for (i = 4; i < 256; i = i + 1) begin
            rom[i] = 8'b0_0000000;
        end
    end

    // Variable-Length Prefix Operand Decoders
    wire [7:0] instr   = rom[pc];
    wire [6:0] op_7bit = instr[6:0]; 
    wire [5:0] op_6bit = instr[5:0]; 

    // Jump Evaluation Flag
    wire jump_to_zero_taken = (instr[7:6] == 2'b11 && acc == 8'h00);

    // Single-cycle Unified Execution Block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc <= 8'h00;
            pc  <= 8'h00;
        end else begin
            
            // --- SINGLE UP-FRONT DEFAULT COUNTER CIRCUIT ---
            pc <= pc + 1'b1;

            // --- ZERO-MUX OVERRIDE ---
            if (jump_to_zero_taken) begin
                pc <= 8'h00; // Directly triggers the hardware Synch-Reset pin
            end

            // Extensible casez prefix matching block for Accumulator Math
            casez (instr[7:6])
                2'b0?: begin 
                    acc <= acc + op_7bit;
                end
                2'b10: begin 
                    acc <= acc ^ op_6bit; 
                end
                default: begin
                    // JZ handled cleanly via the PC overrides above
                end
            endcase
        end
    end

endmodule
