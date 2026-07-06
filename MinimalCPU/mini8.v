module mini8 (
    input  wire       clk, 
    input  wire       rst_n,
    output reg  [7:0] pc,
    input  wire [7:0] instruction,
    
    // External flag monitors
    output wire       c, 
    output wire       z, 
    output wire       n, 
    output wire       v  
);

    // ==========================================================
    // 1. Storage & Wire Aliases (The Background Map)
    // ==========================================================
    reg        c_reg;
    reg [7:0]  tos;        
    reg [7:0]  nos;
    reg [7:0]  n2;

    assign acc      = tos;
    assign carry_in = c_reg;

    assign c   = c_reg;
    assign z   = (tos == 8'd0); 
    assign n   = tos;
    assign v   = 1'b0; 

    // Instruction Decoder Extraction
    wire is_lit    = (instruction[7] == 1'b0);         
    wire [6:0] lit_data = instruction[6:0];      
    
    wire [3:0] grp  = instruction[6:3];          
    wire [2:0] sub_op = instruction[2:0];        

    // Group Selection Localparams
    localparam GRP_ALU   = 4'b0001,
               GRP_JZ    = 4'b0010,
               GRP_STACK = 4'b0100;

    // ALU Sub-instruction Opcodes
    localparam ADD = 3'b000, ADC = 3'b001, SUB = 3'b010, SBC = 3'b011,
               AND = 3'b100, OR  = 3'b101, XOR = 3'b110, DROP = 3'b111;

    // Interconnect Nets
    reg [7:0] nxt_tos;      
    reg       nxt_carry;    
    reg [7:0] nxt_pc;      

    // Factored Next-State Stack Nets
    reg [7:0] nxt_nos;
    reg [7:0] nxt_n2;

    // Direct Control Wire Assertions
    wire do_push = is_lit;
    wire do_drop = (!is_lit && (grp == GRP_ALU)); 

    // ==========================================================
    // 3. CONCERN A: Pure ALU Math Engine
    // ==========================================================
    always @(*) begin
        nxt_carry = c_reg; 
        nxt_tos   = tos;      

        if (is_lit) begin
            nxt_carry = 1'b0;
            nxt_tos   = {1'b0, lit_data}; 
        end else if (grp == GRP_ALU) begin
            case (sub_op)
                ADD:  {nxt_carry, nxt_tos} = tos + nos;
                ADC:  {nxt_carry, nxt_tos} = tos + nos + c_reg;
                SUB:  {nxt_carry, nxt_tos} = tos - nos;
                SBC:  {nxt_carry, nxt_tos} = tos - nos - c_reg;
                AND:  nxt_tos = tos & nos;
                OR :  nxt_tos = tos | nos;
                XOR:  nxt_tos = tos ^ nos;
                DROP: nxt_tos = nos; 
                default: nxt_tos = tos;
            endcase
        end
    end

    // ==========================================================
    // 4. CONCERN B: Centralized Stack Factorization Block
    // ==========================================================
    always @(*) begin
        nxt_nos = nos;
        nxt_n2  = n2;
        nxt_pc  = pc + 1'b1;

        if (do_push) begin
            nxt_nos = tos; 
            nxt_n2  = nos;
        end else if (do_drop) begin
            nxt_nos = n2;    
            nxt_n2  = 8'h00; 
        end else if (!is_lit && (grp == GRP_JZ) && z) begin
            nxt_pc  = nos; 
        end else if (!is_lit && (grp == GRP_STACK)) begin
            case (sub_op)
                default: begin nxt_nos = nos; nxt_n2 = n2; end
            endcase
        end
    end

    // ==========================================================
    // 7. CONCERN E: Flattened Sequential Storage
    // ==========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc    <= 8'h00;
            c_reg <= 1'b0;
            tos   <= 8'h00;
            nos   <= 8'h00;
            n2    <= 8'h00;
        end else begin
            pc    <= nxt_pc;    
            c_reg <= nxt_carry; 
            tos   <= nxt_tos;   
            nos   <= nxt_nos;
            n2    <= nxt_n2;
        end
    end
endmodule
