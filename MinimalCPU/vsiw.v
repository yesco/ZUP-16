// VSIW: Very SHort Instruction Word, "VLIW but for byte instruction"

// SYSTEM RULES:
// 0. act as an experience CPU, FORTH and FPGA engineer.
// 1. change minimal amount of code for feature only.
// 2. don't make temporary "fixed" comments.
// 3. don't use TABs, change indentation, or structure.
// 4. if instructions conflict, say so an make no changes.

`define ALU
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

      case (opcode[2:0])

	`ADD & 7: begin a = t;                b = n;         cin = 0; end 
        `SUB & 7: begin a = ~t;               b = n;         cin = 1; end 
        `INC & 7: begin a = t;                b = `ZEROES;   cin = 1; end 
        `DEC & 7: begin a = t;                b = `ONES;     cin = 0; end 
        `NEG & 7: begin a = ~t;               b = `ZEROES;   cin = 1; end 
	`INV & 7: begin a = ~t;               b = `ZEROES;   cin = 0; end
//	`ABS & 7: begin a = t[W-1] ? ~t : t;  b = `ZEROES;   cin = t[W-1]; end
//	`ZRO & 7: begin a = `ZEROES;          b = `ONES;     cin = t? 1: 0; end
	
      endcase
   end

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
   
   // Condition to spill
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
      T  = n;
      N  = n2;
      N2 = stack_out;
      sd = drop_bit ? SIGNED_DROP : SIGNED_HOLD;

      if (!is_instr) begin

         // VARIABLE-LENGTH LITERAL PIPELINE
         if (!prefix) begin T = {1'b0, op[6:0]};    N = t; N2 = n;  sd = SIGNED_PUSH; end
         else         begin T = (t << 7) | op[6:0]; N = n; N2 = n2; sd = SIGNED_HOLD; end

//      end else begin
// TODO: this shouldn't make a difference!!!!
      end else if (!pc_bit) begin

         // CORE INSTRUCTION SPECIFIC OVERRIDES
         case (opcode)
           // Row 0: SHL
           `SHL: begin
              T = acc;
              if (!drop_bit) begin N = n; N2 = n2; end
           end

           // DROP: (n2 nos tos - n2 nos tos)
	   // NOP:  (n2 nos tos - n2 nos)
           `NOP: begin
              if (!drop_bit) begin T = t; N = n; N2 = n2; end
           end

           // SWAP: (n2 nos tos - n2 tos nos)
           // DUP:  (n2 nos tos - n2 nos tos tos)
           `DUP: begin
              if (drop_bit) begin        N = t; N2 = n; sd = SIGNED_HOLD; end
              else          begin T = t; N = t; N2 = n; sd = SIGNED_PUSH; end
           end

           // TUCK: (... n2 nos tos - ... n2 tos nos tos)
           // OVER: (... n2 nos tos - ... n2 nos tos nos)
           `TUCK: begin
              sd = SIGNED_PUSH;

              if (drop_bit) begin T = t; N = n; N2 = t; end
              else          begin T = n; N = t; N2 = n; end
           end

           // NIP: (... n2 nos tos - n2 tos)
           // ROT: (n2 nos tos - tos n2 nos)
           `ROT: begin
              if (drop_bit) begin T = t;                 end
              else begin                 N = n2; N2 = t; end
           end

	   `ifdef ALU
	   `ADD, `SUB, `INC, `DEC, `NEG, `INV: begin
              T = acc;
	      if (!drop_bit) begin N = n; N2 = n2; end
           end
	   `endif // ALU
	     
	   `ifdef SHIFTERS

	   `ROR:  begin T = { t[0], t[W-1:1] };
	                          N = n; N2 = n2; sd = SIGNED_HOLD; end
	   `ROL:  begin T = { t[W-2:1], t[W-1:0] };
	                          N = n; N2 = n2; sd = SIGNED_HOLD; end
	   `ASR:  begin T = { t[W-1], t[W-1], t[W-2:0] };
	                          N = n; N2 = n2; sd = SIGNED_HOLD; end

	   `SHR:  begin T = t/2;  N = n; N2 = n2; sd = SIGNED_HOLD; end
	   `SHL:  begin T = t*2;  N = n; N2 = n2; sd = SIGNED_HOLD; end
	   `SHR4: begin T = t/16; N = n; N2 = n2; sd = SIGNED_HOLD; end
	   `SHL4: begin T = t*16; N = n; N2 = n2; sd = SIGNED_HOLD; end

	   // on OP! now at lower row +30!
	   // +8 LUT if next to INV!!!! TODO: can we force use of muxes to get it cheaper?
//	   `REV:  begin T = { t[0], t[1], t[2], t[3], t[4], t[5], t[6], t[7] }; // -4 LUT!!!
//                                  N = n; N2 = n2; sd = SIGNED_HOLD; end

	   `endif // SHIFTERS

	   `AND: begin T = t & n; N = n; N2 = n2; sd = SIGNED_HOLD; end
	   `OR : begin T = t & n; N = n; N2 = n2; sd = SIGNED_HOLD; end
	   `XOR: begin T = t & n; N = n; N2 = n2; sd = SIGNED_HOLD; end

	   // XXX
	   // READ WRIT
	   
	   // + 3 LUT!
	   `SIGN: begin T = { !t[W-1], t[W-2:0] }; N = n; N2 = n2; sd = SIGNED_HOLD; end 
	   `TRUE: begin T = ONES;                  N = n; N2 = n2; sd = SIGNED_HOLD; end
	      
	   // RPOP RCPY FOR  RPUSH

           // Catch-all for unallocated opcodes
           default: begin T = t; N = n; N2 = n2; sd = SIGNED_HOLD; end

         endcase

	 `ifdef PC
	 if (!pc_bit) begin 

	    case (op)
	      `RTO : begin end
	      `RCPY: begin end
	      `FOR : begin end
	      `TOR : begin end
	    endcase

	 end else begin
	    // Program Control fused
	    
	    PC= t;

	    // JZ   JN   NEXT JSR
	    case (op)
	      `JZ  : begin end
	      `JN  : begin end
	      `NEXT: begin end
	      `JSR : begin end
	    endcase
	 end
	 `endif // PC
	 
      end else begin 
	 // LOL thsi is so wrong!
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
