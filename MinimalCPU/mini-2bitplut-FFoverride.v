module cpu_top(
    input  wire       clk,        // Onboard 27MHz clock
    input  wire       rst_n,      // Active-low user reset button
    output reg  [4:0] pins_out,   // Lower 5 bits to header pins
    output wire [2:0] leds_out    // Higher 3 bits to onboard LEDs
);

    // Core Data Registers
    reg [7:0] acc;
    wire [7:0] pc; // Converted to wire to accept direct physical DFFCE bindings
    
    integer i;

    // Direct physical routing connections (LEDs are Active-Low)
    assign leds_out = ~acc[7:5];
    always @(*) pins_out = acc[4:0];

    // Fast Fabric Mini-ROM (256 Bytes x 8-bit instructions)
    reg [7:0] rom [0:255];

    initial begin
        rom[8'h00] = 8'b0_0000001; // PC=0: Prefix 0  -> ADD 1   (ACC = ACC + 1)
        rom[8'h01] = 8'b10_001010; // PC=1: Prefix 10 -> XOR 10  (ACC = ACC ^ 6'd10)
        rom[8'h02] = 8'b11_000011; // PC=2: Prefix 11 -> JZ 3    (Jump to 3 if ACC == 0)
        rom[8'h03] = 8'b11_000011; // PC=3: Prefix 11 -> JZ 3    (Self-trapping hardware halt)

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
    
    // Evaluate our execution flags
    wire jump_condition_met = (instr[7:6] == 2'b11 && acc == 8'h00);
    wire halt_on_self = (op_6bit == pc[5:0]);

    assign ctrl = jump_condition_met ? 
                  (halt_on_self ? 2'b01 : 2'b11) : // 01=Hold/Halt, 11=+2 Jump stride
                  2'b10; // 10=+1 Standard Forward Stride

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

    // Combining our next calculated calculation values into a flat 8-bit bus
    wire [7:0] calculated_next_pc = {next_pc3, next_pc2, next_pc1, next_pc0};

    // --- CRITICAL ROUTING FIX: BYPASS THE MULTIPLEXER TREE ---
    wire reg_ce = !jump_condition_met; 
    wire master_clear = !rst_n;

    // Explicitly instantiating the physical registers (8 instances)
    // Pair 0
    DFFCE pc_bit0 (.Q(pc[0]), .D(calculated_next_pc[0]), .CLK(clk), .CE(reg_ce), .CLEAR(master_clear));
    DFFCE pc_bit1 (.Q(pc[1]), .D(calculated_next_pc[1]), .CLK(clk), .CE(reg_ce), .CLEAR(master_clear));
    // Pair 1
    DFFCE pc_bit2 (.Q(pc[2]), .D(calculated_next_pc[2]), .CLK(clk), .CE(reg_ce), .CLEAR(master_clear));
    DFFCE pc_bit3 (.Q(pc[3]), .D(calculated_next_pc[3]), .CLK(clk), .CE(reg_ce), .CLEAR(master_clear));
    // Pair 2
    DFFCE pc_bit4 (.Q(pc[4]), .D(calculated_next_pc[4]), .CLK(clk), .CE(reg_ce), .CLEAR(master_clear));
    DFFCE pc_bit5 (.Q(pc[5]), .D(calculated_next_pc[5]), .CLK(clk), .CE(reg_ce), .CLEAR(master_clear));
    // Pair 3
    DFFCE pc_bit6 (.Q(pc[6]), .D(calculated_next_pc[6]), .CLK(clk), .CE(reg_ce), .CLEAR(master_clear));
    DFFCE pc_bit7 (.Q(pc[7]), .D(calculated_next_pc[7]), .CLK(clk), .CE(reg_ce), .CLEAR(master_clear));

    // Separate Execution Block for data-only modifications
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc <= 8'h00;
        end else begin
            casez (instr[7:6])
                2'b0?: begin // --- PREFIX 0: ADD ---
                    acc <= acc + op_7bit;
                end
                2'b10: begin // --- PREFIX 10: XOR ---
                    acc <= acc ^ op_6bit; 
                end
                default: begin
                    // JZ handled purely by primitive control pins above
                end
            endcase
        end
    end

endmodule
