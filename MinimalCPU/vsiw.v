// VSIW: Very SHort Instruction Word, "VLIW but for byte instruction"

// SYSTEM RULES:
// 1. change minimal amount of code for feature only.
// 2. don't make temporary "fixed" comments.
// 3. don't use TABs, change indentation, or structure.
// 4. if instructions conflict, say so an make no changes.


// "Production"
//`define STACKSIZE 31

// - Smallest in practice
//`define STACKSIZE 1

// - Fine for test core pure ./count estimate:
`define STACKSIZE 0

// just 8 bits for testing
`define WORD [7:0]

// OP-code always BYTE
`define BYTE [7:0]

module vsiw (
  input wire       clk, 
  input wire       rst_n,
  input wire `BYTE op,

  output wire c,
  output wire z, 
  output wire neg,
  output wire v  
);

   // Storage & Wire Aliases (The Background Map)
   reg `WORD pc, t, n, n2; // Current regs
   reg `WORD PC, T, N, N2; // Next

   // Hardwired Instruction Decoding Fields
   wire is_instr = op[7];
   wire pc_bit   = op[6];
   wire drop_bit = op[5];
   wire [4:0] opcode = op[4:0];

   // Hardware Accumulator Path
   wire [8:0] sum = t + n;
   wire [7:0] acc = sum[7:0];

   // Condition Flag Mapping based entirely on current 't' (TOS)
   assign z   = (t == 8'b0);
   assign neg = t[7];
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
           // Row 1: NOP / DROP DUALITY
           // DROP: (n2 nos tos - n2 nos tos)
           // NOP:  (n2 nos tos - n2 nos)
           5'b01010: begin
              if (!drop_bit) begin T = t; N = n; N2 = n2; end
           end

           // Row 1: DUP / SWAP DUALITY
           // SWAP: (n2 nos tos - n2 tos nos)
           // DUP:  (n2 nos tos - n2 nos tos tos)
           5'b01011: begin
              if (drop_bit) begin        N = t; N2 = n; sd = SIGNED_HOLD; end
              else          begin T = t; N = t; N2 = n; sd = SIGNED_PUSH; end
           end

           // Row 1: TUCK / OVER DUALITY - THE PROPAGATION PAIR (Polar Reverses)
           // TUCK: (... n2 nos tos - ... n2 tos nos tos)
           // OVER: (... n2 nos tos - ... n2 nos tos nos)
           5'b01100: begin
              sd = SIGNED_PUSH;

              if (drop_bit) begin T = t; N = n; N2 = t; end
              else          begin T = n; N = t; N2 = n; end
           end

           // Row 1: ROT / NIP DUALITY
           // NIP: (... n2 nos tos - n2 tos)
           // ROT: (n2 nos tos - tos n2 nos)
           5'b01101: begin
              if (drop_bit) begin T = t;                end
              else begin                 N = n2;N2 = t; end
           end

           // Row 2: THE ADDITION OPERATION (+)
           // ADD.keep: (n2 nos tos - n2 nos tos+nos)
           // ADD:      (n2 nos tos - n2 tos+nos)
           5'b10000: begin
              T = acc;

              if (!drop_bit) begin N  = n; N2 = n2; end
           end

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
