module micro_cpu_split_jz (
    input  wire       clk, 
    input  wire       rst_n,
    output reg  [7:0] pc,
    
    // External flag monitors
    output wire       flag_c, 
    output wire       flag_z, 
    output wire       flag_n, 
    output reg        flag_v  
);

    // ==========================================================
    // 1. Storage & Wire Aliases (The Background Map)
    // ==========================================================
    reg [8:0] cacc;        
    wire [7:0] acc;        
    wire       carry_in;   
    
    assign acc      = cacc[7:0];
    assign carry_in = cacc;

    assign flag_c   = carry_in;
    assign flag_z   = (acc == 8'd0); // Evaluated instantly from register state
    assign flag_n   = acc;

    // ==========================================================
    // 2. Decoder & Instruction Splits
    // ==========================================================
    localparam ADD = 3'b000, ADC = 3'b001, SUB = 3'b010, JZ  = 3'b011,
               AND = 3'b100, OR  = 3'b101, XOR = 3'b110, INV = 3'b111;

    wire [7:0] instruction;
    program_rom rom_inst (.address(pc), .data(instruction));

    wire [2:0] op   = instruction[7:5];
    wire [7:0] reg2 = instruction[4:0];

    // Interconnect Nets between Blocks
    reg [7:0] alu_acc;      
    reg       carry_out;    
    wire [8:0] final_cacc = {carry_out, alu_acc}; 
    reg       nxt_v;
    reg [7:0] pc_next;      

    // ==========================================================
    // CONCERN A: Pure ALU Math Engine (No Control Flow / JZ)
    // ==========================================================
    always @(*) begin
        // Default Assignments: Preserve register states
        carry_out = carry_in; 
        alu_acc   = acc;      
        nxt_v     = 1'b0;

        case (op)
            // Arithmetic Operations
            ADD: {carry_out, alu_acc} = acc + reg2;
            ADC: {carry_out, alu_acc} = acc + reg2 + carry_in;
            SUB: {carry_out, alu_acc} = acc - reg2;
            
            // Logical Operations
            AND: alu_acc = acc & reg2;
            OR : alu_acc = acc | reg2;
            XOR: alu_acc = acc ^ reg2;
            INV: alu_acc = ~acc;
            default: alu_acc = acc; // JZ falls here safely; math passes through
        endcase

        // Overflow flags calculation
        if (op == ADD || op == ADC)
            nxt_v = (acc == reg2) && (alu_acc != acc);
        else if (op == SUB)
            nxt_v = (acc != reg2) && (alu_acc != acc);
    end

    // ==========================================================
    // CONCERN B: Pure Control Flow Engine (JZ Lives Privately Here)
    // ==========================================================
    always @(*) begin
        // Default: Step to the next memory address sequentially
        pc_next = pc + 1'b1;

        // Isolate the JZ condition entirely away from the ALU case statement
        if ((op == JZ) && flag_z) begin
            pc_next = {3'b000, reg2[4:0]}; // Override and jump to target
        end
    end

    // ==========================================================
    // CONCERN C: Flattened Sequential Storage (Pure Step Engine)
    // ==========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc     <= 8'h00;
            cacc   <= 9'h000;
            flag_v <= 1'b0;
        end else begin
            pc     <= pc_next;    // Absorbs branching state cleanly
            flag_v <= nxt_v;
            cacc   <= final_cacc; // Absorbs ALU math state cleanly
        end
    end
endmodule
