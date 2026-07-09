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

  // External flag monitors
  output wire c,
  output wire z, 
  output wire neg,
  output wire v  
);

   // ==========================================================
   // 1. Storage & Wire Aliases (The Background Map)
   // ==========================================================
   reg `WORD t, n, n2;     // Current register window state (Lowercase)
   reg `WORD T, N, N2;     // Next combinatorial state variables (Uppercase)

   reg `WORD pc, PC;       // Current and Next Program Counter registers

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
   // TODO: probably useless as transients, need to be flags, if keep at all
   assign c   = (opcode == 3'b100 && is_instr) ? sum[8] : 1'b0;
   assign v   = (opcode == 3'b100 && is_instr) ? ((t[7] == n[7]) && (acc[7] != t[7])) : 1'b0;

   // ==========================================================
   // 2. Physical Data Stack Array & Pointer Management
   // ==========================================================
   reg [4:0]  sp, SP;      // Current and Next Data Stack Pointer registers
   reg        `WORD  stack [0:`STACKSIZE]; // 32-element physical deep stack array

   // Asynchronous Read Port: Always exposing the top value below our N2 register window
   wire `WORD stack_out = stack[sp];
   
   // Explicit condition check tracking physical memory drop/spill movements
   wire       write_en = (SP > sp);

   // Signed Stack Deltas for local decoding tracking
   localparam SIGNED_HOLD = 2'b00;
   localparam SIGNED_PUSH = 2'b01;
   localparam SIGNED_DROP = 2'b11;
   reg [1:0]  sd;

   // ==========================================================
   // 3. Literal Loading Sequencer Flag
   // ==========================================================
   reg        literal_active;
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

   // ==========================================================
   // 4. Combinatorial Data Routing Matrix
   // ==========================================================
   always @(*) begin
      // Hardwired High-Efficiency Structural Defaults
      T  = n;
      N  = n2;
      N2 = stack_out;
      sd = drop_bit ? SIGNED_DROP : SIGNED_HOLD;

      if (!is_instr) begin
         // ------------------------------------------------------
         // VARIABLE-LENGTH LITERAL PIPELINE PATH
         // ------------------------------------------------------
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
         // ------------------------------------------------------
         // CORE INSTRUCTION SPECIFIC OVERRIDES
         // ------------------------------------------------------
         case (opcode)
           // =========================================================
           // 000: NOP / DROP DUALITY
           // =========================================================
           3'b000: begin
              if (!drop_bit) begin // DROP: (n2 nos tos - n2 nos tos)
                 T  = t;
                 N  = n;
                 N2 = n2;
              end
              // else: NOP: (n2 nos tos - n2 nos)
           end

           // =========================================================
           // 001: DUP / SWAP DUALITY
           // =========================================================
           3'b001: begin
              if (drop_bit) begin // SWAP: (n2 nos tos - n2 tos nos)
                 N  = t;
                 N2 = n;
                 sd = SIGNED_HOLD;
              end else begin // DUP: (n2 nos tos - n2 nos tos tos)
                 T  = t;
                 N  = t;
                 N2 = n;
                 sd = SIGNED_PUSH;
              end
           end

           // =========================================================
           // 010: TUCK / OVER DUALITY
           // 010: THE PROPAGATION PAIR (Polar Reverses)
           // =========================================================
           3'b010: begin
              sd = SIGNED_PUSH; // BOTH variants push data down to BRAM

              if (drop_bit) begin  // TUCK: (... n2 nos tos - ... n2 tos nos tos)
                 T  = t;
                 N  = n;
                 N2 = t;
              end else begin  // OVER: (... n2 nos tos - ... n2 nos tos nos)
                 T  = n; // Reduntandt
                 N  = t;
                 N2 = n;
              end
           end

           // =========================================================
           // 011: ROT / NIP DUALITY
           // =========================================================
           3'b011: begin
              if (drop_bit) begin // NIP: (... n2 nos tos - n2 tos)
                 T  = t;
              end else begin // ROT: (n2 nos tos - tos n2 nos)
                 N  = n2;
                 N2 = t;
              end
           end

           // =========================================================
           // 100: THE ADDITION OPERATION (+)
           // =========================================================
           3'b100: begin
              T = acc;

              if (!drop_bit) begin // ADD.keep: (n2 nos tos - n2 nos tos+nos)
                 N  = n;
                 N2 = n2;
              end
              // else: ADD: (n2 nos tos - n2 tos+nos)
           end

           default: begin
              // Catch-all for unallocated opcodes
              T  = t;
              N  = n;
              N2 = n2;
              sd = SIGNED_HOLD; // Net stack depth change is zero
           end
         endcase
      end

      SP = sp + { {4{sd[1]}}, sd[0] };
      
      // Calculate the next execution state destination for Program Counter
      if (is_instr && pc_bit)     PC = t;
      else                        PC = pc + 1;
   end

   // ==========================================================
   // 5. Synchronous State Boundaries Allocation Block
   // ==========================================================
   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         t   <= 0;
         n   <= 0;
         n2  <= 0;
         sp  <= 0;
         pc  <= 0;
      end else begin
         // Commit all register values calculated in combinatorial block
         t   <= T;
         n   <= N;
         n2  <= N2;
         sp  <= SP;
         pc  <= PC;

         // Physical write-out validation layer to catch the spilling frame
         if (write_en) begin
            stack[sp + 5'd1] <= n2;
         end
      end
   end

endmodule
