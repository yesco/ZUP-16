// mini8.v: A minimal play 8-bit CPU
//
// Editing: Only change lines if really needed, any other changes ask
module mini8 (
    input  wire       clk, 
    input  wire       rst_n,
    output reg  [7:0] pc,
    
    // External flag monitors
    output wire       c, 
    output wire       z, 
    output wire       n, 
    output reg        v  
);

    // ==========================================================
    // 1. Storage & Wire Aliases (The Background Map)
    // ==========================================================
    reg [8:0] cacc;        
    wire [7:0] acc;        
    wire       carry_in;   
    
    assign acc      = cacc[7:0];
    assign carry_in = cacc;

    assign c   = carry_in;
    assign z   = (acc == 8'd0); 
    assign n   = acc;

    // ==========================================================
    // 2. INLINE PROGRAM ROM (No Submodule Needed)
    // ==========================================================
    reg [7:0] instruction;
    
    always @(*) begin
        case(pc)
            // Layout: [Opcode 3-bit] [Data/Address 5-bit]
            8'h00: instruction = 8'b101_00010; // OR  Immediate 2   -> Acc = 2
            8'h01: instruction = 8'b010_00001; // SUB Immediate 1   -> Acc = 1 (flag_z=0)
            8'h02: instruction = 8'b011_00001; // JZ to Address 01  -> flag_z is 0, passes through
            8'h03: instruction = 8'b010_00001; // SUB Immediate 1   -> Acc = 0 (flag_z=1)
            8'h04: instruction = 8'b011_00001; // JZ to Address 01  -> flag_z is 1! Loops back!
            8'h05: instruction = 8'b111_00000; // INV Accumulator   -> Escaped! Acc = 255
            default: instruction=8'b011_00000; // Idle lock loop
        endcase
    end

    // Instruction Splits
    localparam ADD = 3'b000, ADC = 3'b001, SUB = 3'b010, JZ  = 3'b011,
               AND = 3'b100, OR  = 3'b101, XOR = 3'b110, INV = 3'b111;

    wire [2:0] op   = instruction[7:5];
    wire [7:0] reg2 = instruction[4:0];

    // Interconnect Nets
    reg [7:0] alu_acc;      
    reg       carry_out;    
    wire [8:0] final_cacc = {carry_out, alu_acc}; 
    reg       nxt_v;
    reg [7:0] pc_next;      

    // ==========================================================
    // 3. CONCERN A: Pure ALU Math Engine
    // ==========================================================
    always @(*) begin
        carry_out = carry_in; 
        alu_acc   = acc;      
        nxt_v     = 1'b0;

        case (op)
            ADD: {carry_out, alu_acc} = acc + reg2;
            ADC: {carry_out, alu_acc} = acc + reg2 + carry_in;
            SUB: {carry_out, alu_acc} = acc - reg2;
            AND: alu_acc = acc & reg2;
            OR : alu_acc = acc | reg2;
            XOR: alu_acc = acc ^ reg2;
            INV: alu_acc = ~acc;
            default: alu_acc = acc; 
        endcase

        if (op == ADD || op == ADC)
            nxt_v = (acc == reg2) && (alu_acc != acc);
        else if (op == SUB)
            nxt_v = (acc != reg2) && (alu_acc != acc);
    end

    // ==========================================================
    // 4. CONCERN B: Pure Control Flow Engine
    // ==========================================================
    always @(*) begin
        pc_next = pc + 1'b1;

        if ((op == JZ) && z) begin
            pc_next = {3'b000, reg2[4:0]}; 
        end
    end

    // ==========================================================
    // 5. CONCERN C: Flattened Sequential Storage
    // ==========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc     <= 8'h00;
            cacc   <= 9'h000;
            v      <= 1'b0;
        end else begin
            pc     <= pc_next;    
            v      <= nxt_v;
            cacc   <= final_cacc; 
        end
    end
endmodule
