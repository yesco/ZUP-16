// VSIW: Very SHort Instruction Word, "VLIW but for byte instruction"

// SYSTEM RULES:
// 0. act as an experience CPU, FORTH and FPGA engineer.
// 1. change minimal amount of code for feature only.
// 2. don't make temporary "fixed" comments.
// 3. don't use TABs, change indentation, or structure.
// 4. if instructions conflict, say so an make no changes.
// %. don't use 1'b1 when 1 can do, same for 0.

`define ALU
`define SHIFTERS

// "Production"
//`define STACKSIZE 31

// - Smallest in practice
//`define STACKSIZE 1

// - Fine for test core pure ./count estimate:
`define STACKSIZE 0
`define RSTACKSIZE 0

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
   reg `WORD pc, t, n, n2, r, r2; // Current regs
   reg `WORD PC, T, N, N2, R, R2; // Next

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
   
   wire `WORD pc_inc = pc + 1;
	 
   // Condition Flag on *NOS* as TOS has the jmp value!
   assign z   = !n;
   assign neg = n[W-1];
   assign c   = 0;
   assign v   = 0;

   // Physical Data Stack Array & Pointer Management
   reg [4:0]  sp, SP, rp, RP;
   
   reg `WORD   stack [0:`STACKSIZE];
   reg `WORD  rstack [0:`RSTACKSIZE];

   // Asynch Read Port: Always top value below our n2/r2
   wire `WORD  stack_out =  stack[sp];
   wire `WORD rstack_out = rstack[sp];
   
   // Condition to spill
   wire       write_sp = (SP > sp);
   wire       write_rp = (RP > rp);

   // Signed Stack Deltas
   localparam HOLD = 2'b00;
   localparam PUSH = 2'b01;
   localparam DROP = 2'b11;
   reg [1:0]  sd, rd;

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

      sd = HOLD;

      if (!is_instr) begin

         // VARIABLE-LENGTH LITERAL PIPELINE
         if (!prefix) begin T = {1'b0, op[6:0]}; N = t; N2 = n; sd = PUSH; end
         else         begin T = (t << 7) | op[6:0]; N = t; N2 = n2;        end

      end else begin

	 // Default Result
	 if (drop_bit) begin T = n; N = n2; N2 = stack_out; sd = DROP; end
	 else          begin T = t; N = t;  N2 = n2;        sd = HOLD; end
	    
         // CORE INSTRUCTION SPECIFIC OVERRIDES
         case (opcode)
           // DROP: (n2 nos tos - n2 nos tos)
	   // NOP:  (n2 nos tos - n2 nos)

           // SWAP: (n2 nos tos - n2 tos nos)
           // DUP:  (n2 nos tos - n2 nos tos tos)
	   `DUP: begin
              if (drop_bit) begin T = n; N = t; N2 = n; sd = HOLD; end
              else          begin T = t; N = t; N2 = n; sd = PUSH; end
           end

           // TUCK: (... n2 nos tos - ... n2 tos nos tos)
           // OVER: (... n2 nos tos - ... n2 nos tos nos)
           `TUCK: begin
              sd = PUSH;
              if (drop_bit) begin T = t; N = n; N2 = t; end
              else          begin T = n; N = t; N2 = n; end
           end

           // NIP: (... n2 nos tos - n2 tos)
           // ROT: (n2 nos tos - tos n2 nos)
           `ROT: begin
              if (drop_bit) begin T = t; N = n2;         end
              else begin          T = n; N = n2; N2 = t; end
           end

	   `ifdef ALU
	   `ADD, `SUB, `INC, `DEC, `NEG, `INV: T = acc;
	   `endif // ALU
	     
	   `ifdef SHIFTERS
	   `ROR:  T = { t[0], t[W-1:1] };
	   `ROL:  T = { t[W-2:0], t[W-1] };
	   `ASR:  T = { t[W-1], t[W-1], t[W-2:0] };

	   `SHR:  T = t /  2;
	   `SHL:  T = t *  2;
	   `SHR4: T = t / 16;
	   `SHL4: T = t * 16;
	   `endif // SHIFTERS

	   `AND: T = t & n;
	   `OR : T = t | n;
	   `XOR: T = t ^ n;

	   // on OP! now at lower row +30!
	   // +8 LUT if next to INV!!!! TODO: can we force use of muxes to get it cheaper?
//	   `REV:  T = { t[0], t[1], t[2], t[3], t[4], t[5], t[6], t[7] };


	   // XXX
	   // READ WRIT
	   
	   // + 3 LUT!
	   `SIGN: begin T = { !t[W-1], t[W-2:0] }; end 
	   `TRUE: begin T = ONES;                  end
	      
	   // RPOP RCPY FOR  RPUSH

         endcase


	 // Any instruction is optionally fused with a pc_bit:
	 //  0( NORMAL STEP: pc++; R Stack stuff
	 //  1) PC SETTERS:  Program Control
	 if (!pc_bit) begin

	    // R stack operations
	    PC = pc_inc; R = r; R2 = r2; rd = HOLD;
	    
	    // OVERRIDES ONLY
	    case (op)
	      `RTO : begin T  = r; N  = t; N2 = n; sd = PUSH; rd = DROP; end
	      `RCPY: begin T  = r; N  = t; N2 = n; sd = PUSH;            end
	      `TOR : begin R  = t; R2 = r;                    rd = PUSH; end
	      `FOR : begin         R2 = pc_inc;               rd = PUSH; end
	    endcase
	    // FOR: keep R inserts pc_inc into R2 and push r2 down
	    
	 end else begin

	    // Usually means return
	    PC = r; R = r2; R2 = rstack_out; rd = DROP;

	    // OVERRIDES ONLY
	    // (jump on flag or behave like !pc_bit)
	    case (op)
	      `JZ  : begin R = r;      R2 = r2; rd = HOLD; PC = z  ? t: pc_inc; end
	      `JN  : begin R = r;      R2 = r2; rd = HOLD; PC = neg? t: pc_inc; end
	      `JSR : begin R = pc_inc; R2 = r;  rd = PUSH; PC =      t;         end
	      `NEXT: begin R = r - 1;  if (!r)             PC =         pc_inc;
                            else begin R2 = r2; rd = HOLD; PC = R2;             end end
	    endcase
	    // NEXT: loop back and dec R if R, otherwise rdrop and continue

	 end 
	 
	 if (sd == DROP) N2 = stack_out;

      end

      // Signed Adjustment
      SP = sp + { {4{sd[1]}}, sd[0] };
      RP = rp + { {4{rd[1]}}, rd[0] };

   end

   // Synch State Update
   always @(posedge clk or negedge rst_n) begin

      if (!rst_n) begin t <= 0; n <= 0; n2 <= 0;  sp <= 0;  pc <= 0;  rp <= 0;  r <= 0; r2 <= 0; end
      else        begin t <= T; n <= N; n2 <= N2; sp <= SP; pc <= PC; rp <= RP; r <= R; r2 <= R2;
         if (write_sp) begin  stack[sp + 1] <= n2; end
         if (write_rp) begin rstack[rp + 1] <= r2; end
      end

   end

endmodule
