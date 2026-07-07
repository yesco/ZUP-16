// iw8.v: A minimal (VL)IW 8-bit stack machine
//
// SYSTEM RULE: chanage minimal amount of code for feature only.


module iw8 (
              input  wire       clk,
              input  wire       rst_n,
              output reg  [7:0] PC,
              input  wire [7:0] op,

              // External flag monitors
              output wire       z,
              );

   // ==========================================================
   // 1. Storage & Wire Aliases (The Background Map)
   // ==========================================================
   reg [7:0]  pc, t, n, r,  PC, T, N, R;
   
   // TODO: maybe test on n if address in t!
   assign z= (t == 0);
   assign n= t[7];

   // ============
   // Instructions
   // ============
   always @(*) begin

      // Defaults
      PC= pc+1; T= t; N= n; R= r;

      // Stack movement
      casez (op[6:5])
	2'b00: ;               // No change
	2'b01: begin N= t; end // "dup"  TODO: push
	2'b10: begin T= n; end // "drop" TODO: refill
	2'b11: ;               // Future
      endcase
       
      // BITS: { instr, drop, ?, ?, ? 
      casez (op)
	// LITERAL
	8'b0???_????: T= op;


	// DROPPERS: (a b -> c)
	8'b11000_000: T= t + n;  // + 
	8'b11000_001: T= t & n;  // AND
	8'b11000_010: T= t | n;  // OR
	8'b11000_011: T= t ^ n;  // XOR
//	8'b11000_100: ram[t]= n; // !    (value remain)
	8'b11000_101: R= t;      // !R
	8'b11000_110: PC= t;     // GOTO
	8'b11000_111: ;          // DROP
//                    T= t;      // NIP (no space!)

	// REGISTER: (a b -> c d)
	8'b10000_000: T= ~t;     // INV
	8'b10000_001: T= t<<1;   // SHL
	8'b10000_010: T= t>>1;   // SHR
//	8'b10100_011: T= ram[t]  // @
	8'b10100_111:
	  begin T= n; N= t; end  // SWAP
	

	// PRODUCER: (a b -> c d e)
	8'b10100_000: ;          // DUP
	8'b10100_001: T= r;      // @R
//	8'b10100_000: T= n;      // OVER
//	8'b10100_000: N2= t;     // TUCK
	8'b10100_001: T= pc;     // ???

	// SPECIALS: 111_xx_xxx

      endcase

   end

   // Update CPU to new state
   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         pc <= 0;  t <= 0; n <= 0; r <= 0;
      end else begin
         pc <= PC; t <= T; n <= N; r <= R;
      end
   end

endmodule
