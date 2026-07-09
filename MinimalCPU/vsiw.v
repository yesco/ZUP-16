// VSIW: Very SHort Instruction Word, "VLIW but for byte"

//`define STACKSIZE 31
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
   wire [2:0] opcode = op[4:2]; // TODO: change to 5 bits

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
   reg        prefix

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         literal_active <= 1'b0;
      end else begin
         if (!is_instr) begin
            literal_active <= 1'b1;
         end else begin
            literal_active <= 1'b0;
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
         if (!literal_active) begin
            T  = {1'b0, op[6:0]};
            N  = t;
            N2 = n;
            sd = SIGNED_PUSH;
         end else begin
            T  = (t << 7) | op[6:0];
            N  = n;
            N2 = n2;
            sd = SIGNED_HOLD;
         end
      end else begin

         // CORE INSTRUCTION SPECIFIC OVERRIDES
         case (opcode)
           // 000: NOP / DROP DUALITY
	   // DROP: (n2 nos tos - n2 nos tos)
           // NOP:  (n2 nos tos - n2 nos)
           3'b000: begin
              if (!drop_bit) begin T = t; N = n; N2 = n2; end
           end

           // 001: DUP / SWAP DUALITY
	   // SWAP: (n2 nos tos - n2 tos nos)
	   // DUP:  (n2 nos tos - n2 nos tos tos)
	   3'b001: begin
              if (drop_bit) begin        N = t; N2 = n; sd = SIGNED_HOLD; end
	      else          begin T = t; N = t; N2 = n; sd = SIGNED_PUSH; end
           end

           // 010: TUCK / OVER DUALITY - THE PROPAGATION PAIR (Polar Reverses)
	   // TUCK: (... n2 nos tos - ... n2 tos nos tos)
	   // OVER: (... n2 nos tos - ... n2 nos tos nos)
           3'b010: begin
              sd = SIGNED_PUSH;

              if (drop_bit) begin T = t; N = n; N2 = t; end
	      else          begin T = n; N = t; N2 = n; end
           end

           // 011: ROT / NIP DUALITY
	   // NIP: (... n2 nos tos - n2 tos)
	   // ROT: (n2 nos tos - tos n2 nos)
	   3'b011: begin
              if (drop_bit) begin T = t;                end
	      else begin                 N = n2;N2 = t; end
           end

           // 100: THE ADDITION OPERATION (+)
	   // ADD.keep: (n2 nos tos - n2 nos tos+nos)
           // ADD:      (n2 nos tos - n2 tos+nos)
           3'b100: begin
              T = acc;

              if (!drop_bit) begin N  = n; N2 = n2; end
           end

           // Catch-all for unallocated opcodes
           default: begin T = t; N = n; N2 = n2; sd = SIGNED_HOLD; end

         endcase
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
