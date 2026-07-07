// iw8.v: A minimal (VL)IW 8-bit stack machine
//
// SYSTEM RULES:
// 1. change minimal amount of code for feature only.
// 2. assignement are "T= expr;"
// 3. don't make temporary "fixed" comments

module iw8 (
              input  wire       clk,
              input  wire       rst_n,
              output reg  [7:0] PC,
              input  wire [7:0] op,

              // External flag monitors
              output wire       z
              );

   // ==========================================================
   // 1. Storage & Wire Aliases (The Background Map)
   // ==========================================================
   // New state use capitals
   reg [7:0]  pc, t, n, r, T, N, R;
   wire       n_sign;
   
   // Testing on N for jump because T is destination!
//   assign z= (t == 0); // LUT: 183
//   assign z= (n == 0); // LUT: 193
//   assign do_jmp= (n == 0) && (op == 8'b11001_100); // LUT: 339
//   assign n_sign= t[7]; // Preserved intent for bit 7 sign monitor

   // ============
   // Instructions
   // ============
   always @(*) begin

      // Defaults
      T= t; N= n; R= r;

      // PC is special
//      PC= do_jmp? t : pc+1; // LUT: 336 !!! (?)
      PC= pc+1;

      // Stack movement
      casez (op[6:5])
	2'b00: ;               // No change
	2'b01: begin N= t; end // "dup"  TODO: push
	2'b10: begin T= n; end // "drop" TODO: refill
	2'b11: ;               // Future
      endcase
       
      // BITS: { instr, drop, push, ?, branch, ... }
      casez (op)
	// -- LITERAL "8 bits" (hi=0, do INV!)
	8'b0???????: T= op;

	// -- DROPPERS: (a b -> c)
	8'b110?0_000: T= t + n;     // + 
	8'b110?0_001: T= t & n;     // AND
	8'b110?0_010: T= t | n;     // OR
	8'b110?0_011: T= t ^ n;     // XOR
//	8'b110?0_100: ram[t]= n;    // !    (value remain)
	8'b110?0_101: R= t;         // !R
//	8'b110?0_110: PC= t;        // GOTO
	8'b110?1_100: if (n==0) PC= t; // %BRANCH
//	8'b110?1_100: ;             // ZBRANCH (handle outside)
//	8'b110?0_111: ;             // DROP
//                    T= t;         // NIP (no space!)

	// -- REGISTER: (a b -> c d)
	8'b100?0_000: T= ~t;        // INV
	8'b100?0_001: T= t<<1;      // SHL
	8'b100?0_010: T= t>>1;      // SHR
//	8'b101?0_011: T= ram[t]     // @
	8'b101?0_111:
	  begin T= n; N= t; end     // SWAP
	

	// -- PRODUCER: (a b -> c d e)
	8'b101?0_000: ;             // DUP
	8'b101?0_001: T= r;         // @R
//	8'b101?0_000: T= n;         // OVER
//	8'b101?0_000: N2= t;        // TUCK
	8'b101?0_010: T= pc;        // ???
	
	// -- SPECIAL: 111_xx_xxx

      endcase

   end

   // Update CPU to new state
   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         pc<= 0;  t<= 0; n<= 0; r<= 0;
      end else begin
         pc<= PC; t<= T; n<= N; r<= R;
      end
   end

endmodule
