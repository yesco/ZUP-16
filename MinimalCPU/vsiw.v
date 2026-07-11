// VSIW: Very SHort Instruction Word, "VLIW but for byte instruction"

// SYSTEM RULES:
// 1. change minimal amount of code for feature only.
// 2. don't make temporary "fixed" comments.
// 3. don't use TABs, change indentation, or structure.
// 4. if instructions conflict, say so an make no changes.


// +22 LUT only (negations and wirings)!
`define ALU

// +29 LUT
`define SHIFTERS

// "Production"
//`define STACKSIZE 31

// - Smallest in practice
//`define STACKSIZE 1

// - Fine for test core pure ./count estimate:
`define STACKSIZE 0

// just 8 bits for testing
`define WORD [W-1:0]

`define ZEROES {W{1'b0}}
`define ONES   {W{1'b1}}

// OP-code always BYTE
`define BYTE [7:0]

`include "vsiw_inc.v"

module vsiw (
  input wire       clk, 
  input wire       rst_n,
  input wire `BYTE op,

  output wire c,
  output wire z, 
  output wire neg,
  output wire v  
);

   // Parameters for Data Width Flex
   localparam W = 8;

   // Storage & Wire Aliases (The Background Map)
   reg `WORD pc, t, n, n2; // Current regs
   reg `WORD PC, T, N, N2; // Next

   // Hardwired Instruction Decoding Fields
   wire is_instr = op[7];
   wire pc_bit   = op[6];
   wire drop_bit = op[5];
   wire [4:0] opcode = op[4:0];

   // Shared Multiplexed Arithmetic/Shift Core Logic
   reg `WORD a, b;
   reg       cin;

   `ifdef ALU
   always @(*) begin
      a = t; b = n; cin = 1'b0;

//      case (opcode) // I think is enough // +30 LUT!!!!
      case (opcode[2:0]) // I think is enough

      `ifdef FISH 
	// Using mismatch sized constants doesn't match ???
	
	`ADD:    begin a = t;                b = n;         cin = 0; end // +5 LUT
        `INC:    begin a = t;                b = `ZEROES;   cin = 1; end
        `DEC:    begin a = t;                b = `ONES;     cin = 0; end
        `SUB:    begin a = ~t;               b = n;         cin = 1; end
	`INV:    begin a = ~t;               b = `ZEROES;   cin = 0; end
        `NEG:    begin a = ~t;               b = `ZEROES;   cin = 1; end

	`else

	3'b000:  begin a = t;                b = n;         cin = 0; end // AND
        3'b001:  begin a = ~t;               b = n;         cin = 1; end // SUB
        3'b010:  begin a = t;                b = `ZEROES;   cin = 1; end // INC
        3'b011:  begin a = t;                b = `ONES;     cin = 0; end // DEC
        3'b100:  begin a = ~t;               b = `ZEROES;   cin = 1; end // NEG
	3'b101:  begin a = ~t;               b = `ZEROES;   cin = 0; end // INV

	`endif
	
      endcase
   end
   `endif // ALU

   `ifdef ALU
   // Single Shared Adder Instance
   wire [W:0] sum = a + b + cin;
   wire `WORD acc = sum[W-1:0];
   `endif
   
   // Condition Flag Mapping based entirely on current 't' (TOS)
   assign z   = (t == {W{1'b0}});
   assign neg = t[W-1];
   assign c   = 0;
   assign v   = 0;

   // Physical Data Stack Array & Pointer Management
   reg [4:0]  sp, SP;
   reg `WORD  stack [0:`STACKSIZE];

   // Asynch Read Port: Always top value below our n2
   wire `WORD stack_out = stack[sp];
   
   // Explicit condition check tracking physical memory drop/spill movements
   wire       write_sp = (SP > sp);

   // Signed Stack Deltas
   localparam SIGNED_HOLD = 2'b00;
   localparam SIGNED_PUSH = 2'b01;
   localparam SIGNED_DROP = 2'b11;
   reg [1:0]  sd;

   // Prefix Literal Loading Sequencer Flag
   reg prefix;

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         prefix <= 1'b0;
      end else begin
         if (!is_instr) begin
            prefix <= 1'b1;
         end else begin
            prefix <= 1'b0;
         end
      end
   end

   // Combinatorial Data Routing Matrix
   always @(*) begin
      // Hardwired High-Efficiency Structural Defaults
      T  = n;
      N  = n2;
      N2 = stack_out;
      sd = drop_bit ? SIGNED_DROP : SIGNED_HOLD;

      if (!is_instr) begin

         // VARIABLE-LENGTH LITERAL PIPELINE PATH
         if (!prefix) begin T = {1'b0, op[6:0]};    N = t; N2 = n;  sd = SIGNED_PUSH; end
         else         begin T = (t << 7) | op[6:0]; N = n; N2 = n2; sd = SIGNED_HOLD; end
      end else if (!pc_bit) begin

         // CORE INSTRUCTION SPECIFIC OVERRIDES
         case (opcode)
           // Row 0: SHL
           `SHL: begin
              T = acc;
              if (!drop_bit) begin N = n; N2 = n2; end
           end

           // Row 1: NOP / DROP DUALITY
           // DROP: (n2 nos tos - n2 nos tos)
           // NOP:  (n2 nos tos - n2 nos)
           `NOP: begin
              if (!drop_bit) begin T = t; N = n; N2 = n2; end
           end

           // Row 1: DUP / SWAP DUALITY
           // SWAP: (n2 nos tos - n2 tos nos)
           // DUP:  (n2 nos tos - n2 nos tos tos)
           `DUP: begin
              if (drop_bit) begin        N = t; N2 = n; sd = SIGNED_HOLD; end
              else          begin T = t; N = t; N2 = n; sd = SIGNED_PUSH; end
           end

           // Row 1: TUCK / OVER DUALITY - THE PROPAGATION PAIR (Polar Reverses)
           // TUCK: (... n2 nos tos - ... n2 tos nos tos)
           // OVER: (... n2 nos tos - ... n2 nos tos nos)
           `TUCK: begin
              sd = SIGNED_PUSH;

              if (drop_bit) begin T = t; N = n; N2 = t; end
              else          begin T = n; N = t; N2 = n; end
           end

           // Row 1: ROT / NIP DUALITY
           // NIP: (... n2 nos tos - n2 tos)
           // ROT: (n2 nos tos - tos n2 nos)
           `ROT: begin
              if (drop_bit) begin T = t;                 end
              else begin                 N = n2; N2 = t; end
           end

	   `ifdef ALU
           // Row 2: THE ADDITION OPERATION (+)
           // ADD.keep: (n2 nos tos - n2 nos tos+nos)
           // ADD:      (n2 nos tos - n2 tos+nos)
	   `ADD, `SUB, `INC, `DEC, `NEG, `INV: begin
              T = acc;
	      if (!drop_bit) begin N = n; N2 = n2; end
           end
	   `endif // ALU
	     
//        `SHL:    begin a = {t[W-2:0], 1'b0}; b = `ZEROES;   cin = 1'b0; end // + 27 LUT
//        `SHL:    begin a = t;                b = t;         cin = 1'b0; end // + 14 LUT

	   `ifdef SHIFTERS // + 29 LUT

	   `ROR:  begin T = { t[0], t[W-1:1] }; /// + 6 for 3: ROR,ROL,ASR
	                          N = n; N2 = n2; sd = SIGNED_HOLD; end // + 14
	   `ROL:  begin T = { t[W-2:1], t[W-1:0] };
	                          N = n; N2 = n2; sd = SIGNED_HOLD; end // + 14
	   `ASR:  begin T = { t[W-1], t[W-1], t[W-2:0] };
	                          N = n; N2 = n2; sd = SIGNED_HOLD; end // + 14

	   `SHR:  begin T = t/2;  N = n; N2 = n2; sd = SIGNED_HOLD; end // + 14
	   `SHL:  begin T = t*2;  N = n; N2 = n2; sd = SIGNED_HOLD; end // + 0!
	   `SHR4: begin T = t/16; N = n; N2 = n2; sd = SIGNED_HOLD; end // + 5
	   `SHL4: begin T = t*16; N = n; N2 = n2; sd = SIGNED_HOLD; end // + 4

	   `REV:  begin T = { t[0], t[1], t[2], t[3], t[4], t[5], t[6], t[7] }; // -4 LUT!!!
                                  N = n; N2 = n2; sd = SIGNED_HOLD; end

	   `endif // SHIFTERS

	   // + 13 LUT :-(
	   `AND: begin T = t & n; N = n; N2 = n2; sd = SIGNED_HOLD; end
	   `OR : begin T = t & n; N = n; N2 = n2; sd = SIGNED_HOLD; end
	   `XOR: begin T = t & n; N = n; N2 = n2; sd = SIGNED_HOLD; end

	   // AND OR XOR

	   // XXX
	   // READ WRIT
	   
	   // SIGN
	   // TRUE
	   
	   // RPOP RCPY FOR  RPUSH
	   // JZ   JN   NEXT JSR

           // Catch-all for unallocated opcodes
           default: begin T = t; N = n; N2 = n2; sd = SIGNED_HOLD; end

         endcase
      end else begin
         // Default path when pc_bit is set (Control Flow takes precedence)
         T = t; N = n; N2 = n2; sd = SIGNED_HOLD;
      end

      SP = sp + { {4{sd[1]}}, sd[0] };
      
      // Calculate the next execution state destination for Program Counter
      if (is_instr && pc_bit) PC = t;
      else                    PC = pc + 1;
   end

   // Synch State Boundaries Allocation Block
   always @(posedge clk or negedge rst_n) begin

      if (!rst_n) begin t <= 0; n <= 0; n2 <= 0;  sp <= 0;  pc <= 0;  end
      // Commit
      else        begin t <= T; n <= N; n2 <= N2; sp <= SP; pc <= PC;
         if (write_sp) begin stack[sp + 5'd1] <= n2; end
      end

   end

endmodule
