// mini8.v: A mini8 stack cpu
//
// Editing: Only change lines if really needed, any other changes ask

// --- Master Global Architecture Definitions ---
`define BITSY   4'b0000
`define BITSY2  4'b0000
`define LOOP    4'b0010
`define LOOP2   4'b0011
`define JSRRET  4'b0100
`define JSRRET2 4'b0101
`define BRANCH  4'b0110
`define BRANCH2 4'b0111
`define READ    4'b1000
`define READ2   4'b1000
`define WRITE   4'b1010
`define WRITE2  4'b1011
`define REG     4'b1100
`define STACK   4'b1101
`define ALU     4'b1110
`define RSTACK  4'b1111

// BITSY Sub-instruction Opcodes
`define SIGN   3'b000
`define bit14  3'b001
`define bit13  3'b010
`define bit12  3'b011
`define bit11  3'b100
`define bit10  3'b101
`define bit09  3'b110
`define bit08  3'b111
`define bit07  3'b000
`define bit06  3'b001
`define bit05  3'b010
`define bit04  3'b011
`define bit03  3'b100
`define bit02  3'b101
`define bit01  3'b110
`define bit00  3'b111

// ALU Sub-instruction Opcodes
`define ADD  3'b000
`define ADC  3'b001
`define SUB  3'b010
`define SBC  3'b011
`define AND  3'b100
`define OR   3'b101
`define XOR  3'b110
`define DROP 3'b111

// Register Ops (not moving stack)
`define INC  3'b000
`define DEC  3'b001
`define ROR  3'b010
`define ASR  3'b011
`define SHR  3'b100
`define SHR4 3'b101
`define SHL  3'b110
`define SHL4 3'b111

// STK Sub-instruction Opcodes
`define st0  3'b000
`define MUL  3'b001
`define NOP  3'b010
`define ROT  3'b011
`define SWAP 3'b100
`define OVER 3'b101
`define TUCK 3'b110
`define DUP  3'b111

// --- Fused Mnemonic String + 8-Bit Opcode Macro Constants ---
`define iADD  {"ADD ", {1'b1, `ALU,   `ADD}}
`define iADC  {"ADC ", {1'b1, `ALU,   `ADC}}
`define iSUB  {"SUB ", {1'b1, `ALU,   `SUB}}
`define iSBC  {"SBC ", {1'b1, `ALU,   `SBC}}
`define iAND  {"AND ", {1'b1, `ALU,   `AND}}
`define iOR   {"OR  ", {1'b1, `ALU,   `OR}}
`define iXOR  {"XOR ", {1'b1, `ALU,   `XOR}}
`define iDROP {"DROP", {1'b1, `ALU,   `DROP}}

`define ist0  {"st0 ", {1'b1, `STACK, `st0}}
`define iMUL  {"MUL ", {1'b1, `STACK, `MUL}}
`define iNOP  {"NOP ", {1'b1, `STACK, `NOP}}
`define iROT  {"ROT ", {1'b1, `STACK, `ROT}}
`define iSWAP {"SWAP", {1'b1, `STACK, `SWAP}}
`define iOVER {"OVER", {1'b1, `STACK, `OVER}}
`define iTUCK {"TUCK", {1'b1, `STACK, `TUCK}}
`define iDUP  {"DUP ", {1'b1, `STACK, `DUP}}

`define iINC  {"INC ", {1'b1, `REG,   `INC}}
`define iDEC  {"DEC ", {1'b1, `REG,   `DEC}}
`define iROR  {"ROR ", {1'b1, `REG,   `ROR}}
`define iASR  {"ASR ", {1'b1, `REG,   `ASR}}
`define iSHR  {"SHR ", {1'b1, `REG,   `SHR}}
`define iSHR4 {"SHR4", {1'b1, `REG,   `SHR4}}
`define iSHL  {"SHL ", {1'b1, `REG,   `SHL}}
`define iSHL4 {"SHL4", {1'b1, `REG,   `SHL4}}

`define iSIGN   {"SIGN", {1'b1, `BITSY, `SIGN}}
`define ibit14  {"bt14", {1'b1, `BITSY, `bit14}}
`define ibit13  {"bt13", {1'b1, `BITSY, `bit13}}
`define ibit12  {"bt12", {1'b1, `BITSY, `bit12}}
`define ibit11  {"bt11", {1'b1, `BITSY, `bit11}}
`define ibit10  {"bt10", {1'b1, `BITSY, `bit10}}
`define ibit09  {"bt09", {1'b1, `BITSY, `bit09}}
`define ibit08  {"bt08", {1'b1, `BITSY, `bit08}}

`define ibit07  {"bt07", {1'b1, `BITSY2, `bit07}}
`define ibit06  {"bt06", {1'b1, `BITSY2, `bit06}}
`define ibit05  {"bt05", {1'b1, `BITSY2, `bit05}}
`define ibit04  {"bt04", {1'b1, `BITSY2, `bit04}}
`define ibit03  {"bt03", {1'b1, `BITSY2, `bit03}}
`define ibit02  {"bt02", {1'b1, `BITSY2, `bit02}}
`define ibit01  {"bt01", {1'b1, `BITSY2, `bit01}}
`define ibit00  {"bt00", {1'b1, `BITSY2, `bit00}}

`define iJZ   {"JZ  ", {1'b1, `BRANCH,  3'b000}}
`define iJNZ  {"JNZ ", {1'b1, `BRANCH2, 3'b000}}

module mini8 (
              input  wire       clk, 
              input  wire       rst_n,
              output reg  [7:0] pc,
              input  wire [7:0] op,

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

   assign acc  = tos;
   assign c_in = c_reg;

   assign c = c_reg;
   assign z = (tos == 8'd0); 
   assign n = tos;
   assign v = 1'b0; 

   // Instruction Decoder Extraction
   wire       is_lit   = (op[7] == 1'b0);         
   wire [6:0] lit_data = op[6:0];      
   
   wire [3:0] grp    = op[6:3];          
   wire [2:0] sub_op = op[2:0];        

   // Interconnect Nets
   reg [7:0]  nxt_tos;
   reg        nxt_c;    
   reg [7:0]  nxt_pc;      

   // Factored Next-State Stack Nets
   reg [7:0]  nxt_nos;
   reg [7:0]  nxt_n2;

   // --- Single-Adder Control Mux Nets ---
   reg [7:0]  b_mux;
   reg [7:0]  a_mux;
   reg        cin;

   // ==========================================================
   // 3. CONCERN A: Pure ALU Math & Stack Engine
   // ==========================================================
   always @(*) begin
      // Top-level initializations
      nxt_tos   = tos;
      nxt_nos   = nos;
      nxt_n2    = n2;
      nxt_c     = c_reg; 
      nxt_pc    = pc + 1'b1;

      // Shared Operand Route Baseline Defaults
      b_mux = tos;
      a_mux = nos;
      
      cin   = 1'b0;

      if (is_lit) begin
         // PUSH logic embedded directly
         nxt_c   = 1'b0;
         nxt_tos = {1'b0, lit_data};
         nxt_nos = tos;
         nxt_n2  = nos;

      end else if (grp == `ALU || grp == `REG) begin

         // PASS 1: Set up the routing parameters for arithmetic operations
         case (sub_op)
           `ADD: begin b_mux = tos;  cin = 0;     end
           `ADC: begin b_mux = tos;  cin = c_reg; end
           `SUB: begin b_mux = ~tos; cin = 1;     end
           `SBC: begin b_mux = ~tos; cin = ~c_reg;end
         endcase 

         if (grp == `REG) begin 
            case (sub_op)
              `INC: begin b_mux = tos; a_mux =  0;  cin = 1; end
              `DEC: begin b_mux = tos; a_mux = ~0;  cin = 0; end
            endcase
         end

         // THE ONLY ARITHMETIC LINE
         {nxt_c, nxt_tos} = a_mux + b_mux + cin;

         // PASS 2: Logical operations cleanly overwrite nxt_tos if active
         if (grp == `ALU) begin
            // DROP logic embedded directly
            nxt_nos = n2;
            nxt_n2  = 8'h00;
            case (sub_op)
              `AND:  nxt_tos = tos & nos;
              `OR :  nxt_tos = tos | nos;
              `XOR:  nxt_tos = tos ^ nos;
              `DROP: nxt_tos = nos;
            endcase
         end else begin
            case (sub_op)
              `SHR:  begin nxt_tos = tos /  2; nxt_c = tos[0]; end 
              `SHR4: begin nxt_tos = tos / 16; nxt_c = tos[4]; end
              `SHL:  begin nxt_tos = tos *  2; nxt_c = tos[7]; end 
              `SHL4: begin nxt_tos = tos * 16; nxt_c = tos[3]; end 
            endcase
         end

      end else if (grp == `STACK) begin
         
         case (sub_op)
           `OVER: begin nxt_tos = nos; nxt_nos = tos; nxt_n2  = nos; end
           `SWAP: begin nxt_tos = nos; nxt_nos = tos;                end
           `DUP:  begin                nxt_nos = tos; nxt_n2  = nos; end
         endcase

      end else if (grp == `BRANCH) begin
         if (z) begin
            nxt_pc = nos;
         end
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
         c_reg <= nxt_c; 
         tos   <= nxt_tos;   
         nos   <= nxt_nos;
         n2    <= nxt_n2;
      end
   end
endmodule
