// VSIW: Very SHort Instruction Word, "VLIW but for byte instruction"

// SYSTEM RULES:
// 0. act as an experience CPU, FORTH and FPGA engineer.
// 1. change minimal amount of code for feature only.
// 2. don't make temporary "fixed" comments.
// 3. don't use TABs, change indentation, or structure.
// 4. if instructions conflict, say so an make no changes.
// %. don't use 1'b1 when 1 can do, same for 0.

`define W 8

// OPTIONALS

`define ALU


// (- 317 211) = +106
// (- 381 211) = 170 ??? this is Refill R2 from rstack!!!?!??!?
// (- 322 209) = 113 when REMOVED refill R2!
// NOW: (- 353 234) = 119 LUT extra, if (DROP) N2= out; but not R2 and rstack!
`define MEM // + 119 LUT! not including memory!

`define SHIFTERS // -1 LUT!
//`define ROTATIONS // + 10 LUT
//`define REVERSE // + 4 LUT


// "Production"
//`define STACKSIZE 31

// - Smallest in practice
//`define STACKSIZE 1

// - Fine for test core pure ./count estimate:
`define STACKSIZE 0
`define RSTACKSIZE 0

// just 8 bits for testing
`define WORD [`W-1:0]

`define ZEROES {`W{1'b0}}
`define ONES   {`W{1'b1}}

// OP-code always BYTE
`define BYTE [7:0]

`include "vsiw_inc.v"

module vsiw (
  input wire  clk, 
  input wire  rst_n,
  input wire  `BYTE op,

  `ifdef MEM
  // Port A: Dedicated to Instruction Fetch (Read-Only)
  output reg  mem_en_a,
  output reg  `WORD mem_addr_a,
  input wire  `BYTE mem_rdata_a, // Instruction stream matches BYTE width

  // Port B: Dedicated to Data Operations (Read/Write)
  output reg  mem_en_b,
  output reg  mem_we_b,
  output reg  `WORD mem_addr_b,
  output reg  `WORD mem_wdata_b,
  input wire  `WORD mem_rdata_b,
  `endif // MEM

  output wire c,
  output wire z, 
  output wire neg,
  output wire v  
);

   // this saves 2 LUT, but fun ROR ROL ASR cost more...
   function `WORD reverse;
      input `WORD in;
      integer i;
      begin
         for (i = 0; i < `W; i = i + 1)
            reverse[i] = in[`W - 1 - i];
      end
   endfunction

   // Storage & Wire Aliases (The Background Map)
   reg `WORD pc, t_reg, n, n2, r, r2; // Current regs
   reg `WORD PC, T,     N, N2, R, R2; // Next

   // "T Bypass" - enables TRUE 1 cycle READ!
   `ifdef MEM
   wire `WORD t = mem_loading ? mem_rdata_b : t_reg;
   `else
   wire `WORD t = t_reg;
   `endif // MEM

   // Hold execution one cycle (or two?)
   reg [1:0] hold;
   
   // Hardwired Instruction Decoding Fields
   wire is_instr     = op[7];
   wire pc_bit       = op[6];
   wire drop_bit     = op[5];
   wire [4:0] opcode = op[4:0];

   // Shared Multiplexed Arithmetic/Shift Core Logic
   reg `WORD a, b;
   reg       cin;

   reg       mem_loading;

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
//	`ABS & 7: begin a = t[`W-1] ? ~t : t;  b = `ZEROES;   cin = t[W-1]; end
//	`ZRO & 7: begin a = `ZEROES;          b = `ONES;     cin = t? 1: 0; end
      endcase
   end

   // Single Shared Adder Instance
   wire [`W:0] sum = a + b + cin;
   wire `WORD acc = sum[`W-1:0];
   `endif
   
   wire `WORD pc_inc = pc + 1;
	 
   // Condition Flag on *NOS* as TOS has the jmp value!
   assign z   = !n;
   assign neg = n[`W-1];
   assign c   = 0;
   assign v   = 0;

   // Physical Data Stack Array & Pointer Management
   reg [4:0]  sp, SP, rp, RP;
   
   reg `WORD   stack [0:`STACKSIZE];
   reg `WORD  rstack [0:`RSTACKSIZE];

   // Asynch Read Port: Always top value below our n2/r2
   wire `WORD  stack_out =  stack[sp];
   wire `WORD rstack_out = rstack[rp];
   
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

   // Realized Prefix Literal Loading Sequencer Flag
   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         prefix                <= 0;
         mem_loading           <= 0;
      end else if (!hold) begin
         if (!is_instr) prefix <= 1;
         else           prefix <= 0;
         mem_loading           <= !is_instr && (opcode == `READ);
      end
   end
   
   // Combinatorial Data Routing Matrix
   always @(*) begin
      sd = HOLD;
      rd = HOLD;

      // Global default calculates the next sequential step address
      PC = pc_inc;

      `ifdef MEM
      // Port A Defaults: Instruction Fetch Pipeline
      mem_en_a   = 1;
      mem_addr_a = PC;

      // Port B Defaults: Data Stack Memory Engine
      mem_en_b    = 0;
      mem_we_b    = 0;
      mem_addr_b  = t;
      mem_wdata_b = t;
      `endif // MEM

      if (hold) begin
         // Strictly lock the next state wires to current values during initialization
         PC = pc; T = t; N = n; N2 = n2; R = r; R2 = r2;
      end else if (!is_instr) begin

         // VARIABLE-LENGTH LITERAL PIPELINE
         if (!prefix) begin T = op;                 N = t; N2 = n; sd = PUSH; end
         else         begin T = (t << 7) | op[6:0]; N = t; N2 = n2;           end
	 
      end else begin

	 // Default Result by drop_bit flag
	 if (drop_bit) begin T = n; N = n2;                 sd = DROP; end // refill
	 else          begin T = t; N = n;  N2 = n2;        sd = HOLD; end // keep
	    
         // CORE INSTRUCTION SPECIFIC OVERRIDES
         case (opcode)
           // DROP: (n2 nos tos - n2 nos tos)
	   // NOP:  (n2 nos tos - n2 nos)
	   // - no code needed!
	   
           // SWAP: (n2 nos tos - ... n2 tos nos)
           // DUP:  (n2 nos tos - n2 nos tos tos)
	   `DUP: begin
              if (drop_bit) begin T = n; N = t; N2 = n2; sd = HOLD; end // SWAP
              else          begin T = t; N = t; N2 = n;  sd = PUSH; end // DUP
           end

           // OVER: (... n2 nos tos - ... n2 nos tos nos)
           // TUCK: (... n2 nos tos - ... n2 tos nos tos)
           `OVER: begin
              sd = PUSH;
              if (drop_bit) begin T = n; N = t; N2 = n; end // OVER
              else          begin T = t; N = n; N2 = t; end // TUCK
           end

           // NIP: (... n2 nos tos - ... n2 tos)
           // ROT: (n2 nos tos     - tos n2 nos)
           `ROT: begin
	      N = n2; 
              if (drop_bit) begin T = t; end // NIP
              else begin          T = n; N2 = t;         end // ROT
           end
	   `ifdef ALU
	   `ADD, `SUB, `INC, `DEC, `NEG, `INV: T = acc;
	   `endif // ALU
	     

	   `ifdef SHIFTERS

	   // 225 LUT baseline, 277 LUT if use functions so don't
	    `ifdef ROTATIONS
	   `ROR:  T = { t[0], t[`W-1:1] };
           `ROL:  T = { t[`W-2:0], t[`W-1] };
	   `ASR:  T = { t[`W-1], t[`W-1:1] };
	    `endif // ROTATIONS

	   `SHR:  T = t >> 1;
	   `SHL:  T = t << 1;
	   `SHR4: T = t >> 4;
	   `SHL4: T = t << 4;

	   `endif // SHIFTERS

	   `AND: T = t & n;
	   `OR : T = t | n;
	   `XOR: T = t ^ n;

	   // on OP! now at lower row +30!

	   `ifdef REVERSE
	   // +8 LUT if next to INV!!!! TODO: can we force use of muxes to get it cheaper?
//	   `REV:  T = { t[0], t[1], t[2], t[3], t[4], t[5], t[6], t[7] }; // +7 LUT
//	   `REV: begin: rev_block integer i; for(i=0; i<`W; i=i+1) T[i] = t[`W-1-i]; end // +66 LUT!!!!
	   `REV: T = reverse(t); // +5 LUT
	   `endif // REVERSE
	   


	   // + 3 LUT!
	   `SIGN: begin T = { !t[`W-1], t[`W-2:0] }; end 
	   `TRUE: begin T = `ONES;                   end
	      
	   // RPOP RCPY FOR  RPUSH



	   // MEMORY INTERFACE

 	   // READ.drop: ( ... n2 n addr -      ... n2 n val ) == "FORTH: replace addr w val"
	   // READ.keep  ( ... n2 n addr - ... n2 n addr val ) == "keep address, push val"
	   // Notice: "we shifted words 'drop' 'keep' one level, diff still==1"
	   // TODO: consider replacing addr with addr+1 ! (and maybe revere arg as n++ cannot?)
	   `ifdef MEM
	   `READ: begin
              mem_en_b   = 1;
              mem_addr_b = t;

              if (drop_bit) begin T = t; N = n; N2 = n2; sd = HOLD; end
              else          begin T = t; N = t; N2 = n;  sd = PUSH; end
           end

	   // WRIT.drop: ( ... n2 addr val -     ... n2 addr ) == "FORTH" (ok need one user drop)
	   // WRIT.keep  ( ... n2 addr val - ... n2 addr val ) 
	   // TODO: consider replacing addr with addr+1 ! (and maybe revere arg as n++ cannot?)
	   // TODO: can we reuse he ALU for this!
	   `WRIT: begin 
              mem_en_b    = 1;
              mem_we_b    = 1;
              mem_addr_b  = n;
              mem_wdata_b = t;
              if (drop_bit) begin T = n; N = n2; end
              else          begin T = t; N = n;  N2 = n2;        end
           end
	   `endif // MEM

         endcase


	 // Any instruction is optionally fused with a pc_bit:
	 //  0( NORMAL STEP: normal instruction; pc++; (incl R Stack)
	 //  1) PC SETTERS:  - " - & ctrl flow;  pc= ? (incl ret/jumps/jsr/loop)
	 if (!pc_bit) begin

	    // Normal instructions & R stack ops
	    PC = pc_inc; R = r; R2 = r2; rd = HOLD;
	    
	    // OVERRIDES
	    case (op)
	      `RTO : begin T  = r; N  = t; N2 = n; sd = PUSH; R2= rstack_out; rd = DROP; end
	      `RCPY: begin T  = r; N  = t; N2 = n; sd = PUSH;                            end
	      `TOR : begin R  = t; R2 = r;                                    rd = PUSH; end
	      `FOR : begin         R2 = pc_inc;                               rd = PUSH; end
	    endcase
	    // FOR: keep R inserts pc_inc into R2 and push r2 down
	    
	 end else begin

	    // Usually means return
	    PC = r; R = r2; R2 = rstack_out; rd = DROP;

	    // OVERRIDES
	    // (jump on flag or behave like !pc_bit)
	    case (op)
	      `JZ  : begin R = r;      R2 = r2; rd = HOLD; PC = z  ? t: pc_inc; end
	      `JN  : begin R = r;      R2 = r2; rd = HOLD; PC = neg? t: pc_inc; end
	      `JSR : begin R = pc_inc; R2 = r;  rd = PUSH; PC =      t;         end
	      `NEXT: begin R = r - 1;  if (!r)             PC =         pc_inc;         // rdrop one!
                            else begin R2 = r2; rd = HOLD; PC = r2;             end end
	    endcase
	    // NEXT: loop back and dec R if R, otherwise rdrop and continue

	 end 
	 
	 // Refills
	 if (sd == DROP) N2 =  stack_out; // this decreases LUT w 20
//	 if (rd == DROP) R2 = rstack_out; // if removed 357
         // ^^^---- TODO: MEM: this SINGLE line causes LUT: 317 => 447
	 
      end

      // Signed Adjustment
      SP = sp + { {4{sd[1]}}, sd[0] };
      RP = rp + { {4{rd[1]}}, rd[0] };

   end


   // Synch State Update (Synchronous AND Reset with 2-Stage BRAM Warmup)
   always @(posedge clk) begin

      if (!rst_n)        begin t_reg <= 0;     n <= 0; n2 <= 0;  sp <= 0;  pc <= 0; rp <= 0;  r <= 0; r2 <= 0;  hold <= 2'b11;     end
      else if (hold[1])  begin t_reg <= t_reg; n <= n; n2 <= n2; sp <= sp; pc <= 0; rp <= rp; r <= r; r2 <= r2; hold <= hold >> 1; end
      else if (hold[0])  begin t_reg <= t_reg; n <= n; n2 <= n2; sp <= sp;pc<=`ONES;rp <= rp; r <= r; r2 <= r2; hold <= hold >>1; end
      else            begin t_reg <= T;     n <= N; n2 <= N2; sp <= SP; pc <= PC; rp <= RP; r <= R; r2 <= R2; hold <= 0;
	 // Spills
	 if (write_sp) begin  stack[sp + 1] <= n2; end
	 if (write_rp) begin rstack[rp + 1] <= r2; end
      end
   end

endmodule
