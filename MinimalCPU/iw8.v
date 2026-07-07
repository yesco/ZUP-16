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
   assign z= (n == 0); // LUT: 193
//   assign do_jmp= (n == 0) && (op == 8'b110??_100); // LUT: 339
//   assign n_sign= t; // Preserved intent for bit 7 sign monitor

   // ============
   // Instructions
   // ============
   always @(*) begin

      // Defaults
      T= t; N= n; R= r;

      // PC is special
//      PC= do_jmp? t : pc+1; // LUT: 336 !!! (?)

      PC = pc+1;

      // Stack movement
      casez (op[6:5])
	2'b00: ;               // No change
	2'b01: begin N= t; end // "dup"  TODO: push
	2'b10: begin T= n; end // "drop" TODO: refill
	2'b11: ;               // Future
      endcase
       
      // BITS: { !n (1 bit), op[7:0] (8 bits) } = 9 bits total
      casez ({!n, op})
	// -- LITERAL "8 bits" (hi=0, do INV!)
	9'b?_0???????: T= op;

	// -- DROPPERS: (a b -> c)
	9'b?_110??_000: T= t + n;     // + 
	9'b?_110??_001: T= t & n;     // AND
	9'b?_110??_010: T= t | n;     // OR
	9'b?_110??_011: T= t ^ n;     // XOR
//	9'b?_110??_100: ram[t]= n;    // !    (value remain)
	9'b?_110??_101: R= t;         // !R
	9'b?_11010_110: PC= t;        // GOTO (Bit 4=1: Always jumps regardless of !n flag state)
	9'b1_11000_110: PC= t;        // %BRANCH (Bit 4=0 AND !n=1: Conditional Jump executes)
//	9'b110??_100: if (z) PC= t; // %BRANCH
//	9'b110??_100: ;             // ZBRANCH (handle outside)
	9'b?_110??_111: ;             // DROP
//                    T= t;         // NIP (no space!)

	// -- REGISTER: (a b -> c d)
	9'b?_100??_000: T= ~t;        // INV
	9'b?_100??_001: T= t<<1;      // SHL
	9'b?_100??_010: T= t>>1;      // SHR
//	9'b?_101??_011: T= ram[t]     // @
	9'b?_101??_111:
	  begin T= n; N= t; end     // SWAP
	

	// -- PRODUCER: (a b -> c d e)
	9'b?_101??_000: ;             // DUP
	9'b?_101??_001: T= r;         // @R
//	9'b?_101??_000: T= n;         // OVER
//	9'b?_101??_000: N2= t;        // TUCK
	9'b?_101??_010: T= pc;        // ???

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
