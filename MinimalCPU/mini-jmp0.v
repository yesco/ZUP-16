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
        // Prefix 11 -> JZ 0. Lowest 6 bits are ignored by the hardware completely.
        rom[8'h02] = 8'b11_000000; // PC=2: If ACC == 0, jump to 0. Else PC = 3.
        rom[8'h03] = 8'b11_000000; // PC=3: Fallback trap

        // Zero out remaining 256-byte ROM space cleanly
        for (i = 4; i 
        end
    end

endmodule
