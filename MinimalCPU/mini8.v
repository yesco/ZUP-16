// mini8.v: A mini8 stack cpu
//
// Editing: Only change lines if really needed, any other changes ask

`include "mini8_inc.v"

module mini8 (
              input  wire       clk, 
              input  wire       rst_n,
              output reg  [7:0] pc,
              input  wire [7:0] op,

              // External flag monitors
              output wire       c, 
              output wire       z, 
              output wire       n, 
              output wire       v  
              );

   // ==========================================================
   // 1. Storage & Wire Aliases (The Background Map)
   // ==========================================================
   reg        c_reg;
   reg [7:0]  tos;        
   reg [7:0]  nos;
   reg [7:0]  n2;

   `ifdef ENABLE_SPILL_STACK
   // 32-element Overflow Stack RAM and Pointer
   reg [7:0]  stack_mem [0:31];
   reg [4:0]  sp;
   reg [4:0]  nxt_sp;
   `endif

   assign acc  = tos;
   assign c_in = c_reg;

   assign c = c_reg;
   assign z = (tos == 8'd0); 
   assign n = tos;
   assign v = 0;

   // Instruction Decoder Extraction
   wire       is_lit   = (op[7] == 0); // DON'T CHANGE: you keep messing it up!
   wire [6:0] lit_data = op[6:0];      
   
   wire [3:0] grp    = op[6:3];          
   wire [2:0] sub_op = op[2:0];        

   // Interconnect Nets
   reg [7:0]  nxt_tos;
   reg        nxt_c;    
   reg [7:0]  nxt_pc;      

   // Factored Next-State Stack Nets
   reg [7:0]  nxt_nos;
   reg [7:0]  nxt_n2;

   // --- Single-Adder Control Mux Nets ---
   reg [7:0]  b_mux;
   reg [7:0]  a_mux;
   reg        cin;

   // ==========================================================
   // 3. CONCERN A: Pure ALU Math & Stack Engine
   // ==========================================================
   always @(*) begin

      // Top-level initializations
      nxt_tos   = tos;
      nxt_nos   = nos;
      nxt_n2    = n2;
      nxt_c     = c_reg; 
      nxt_pc    = pc + 1;
      `ifdef ENABLE_SPILL_STACK
      nxt_sp    = sp;
      `endif

      // Shared Operand Route Baseline Defaults
      b_mux = tos;
      a_mux = nos;
      
      cin   = 0;

      if (is_lit) begin

         // PUSH logic embedded directly + RAM Spill
         nxt_c   = 0;
         nxt_tos = {1'b0, lit_data};
         nxt_nos = tos;
         nxt_n2  = nos;
         `ifdef ENABLE_SPILL_STACK
         nxt_sp  = sp + 1;
         `endif

      end else if (grp == `ALU || grp == `REG) begin

         // PASS 1: Set up the routing parameters for arithmetic operations
         case (sub_op)
           `ADD: begin b_mux = tos;  cin = 0;     end
           `ADC: begin b_mux = tos;  cin = c_reg; end
           `SUB: begin b_mux = ~tos; cin = 1;     end
           `SBC: begin b_mux = ~tos; cin = ~c_reg;end
         endcase 

         if (grp == `REG) begin 

	    // TODO: if INC(+DEC) was ALU blocked, would it be chepaer?
            case (sub_op)
              `INC: begin b_mux = tos; a_mux =  0;  cin = 1; end
              `DEC: begin b_mux = tos; a_mux = ~0;  cin = 0; end
            endcase

         end

         // THE ONLY ARITHMETIC LINE
         {nxt_c, nxt_tos} = a_mux + b_mux + cin;

         // PASS 2: Logical operations cleanly overwrite nxt_tos if active
         if (grp[1]) begin // (this cheaply detects ALU)

            // DROP logic embedded directly
            nxt_nos = n2;
            `ifdef ENABLE_SPILL_STACK
            nxt_sp  = sp - 1;
            `endif

            // nxt_n2 is bypassed here; handled cleanly at the clock edge below
            case (sub_op)
              `AND:  nxt_tos = tos & nos;
              `OR :  nxt_tos = tos | nos;
              `XOR:  nxt_tos = tos ^ nos;
              `DROP: nxt_tos = nos;
            endcase

         end else if (sub_op[2]) begin

            case (sub_op)
	      `SHR:  begin nxt_tos = tos /  2; end 
	      `SHR4: begin nxt_tos = tos / 16; end
	      `SHL:  begin nxt_tos = tos *  2; end 
	      `SHL4: begin nxt_tos = tos * 16; end 
            endcase
            
	    // saves one LUT, lol
	    if (grp == `REG && sub_op[2])
	      nxt_c = sub_op[1] ? (sub_op[0] ? tos[3] : tos[7]) : (sub_op[0] ? tos[4] : tos[0]);

         end

      end else if (grp == `STACK) begin
         
         case (sub_op)
           `OVER: begin nxt_tos = nos; nxt_nos = tos; nxt_n2  = nos; `ifdef ENABLE_SPILL_STACK nxt_sp = sp + 1; `endif end // Pushes onto stack
           `SWAP: begin nxt_tos = nos; nxt_nos = tos;                                 end // No depth change
           `DUP:  begin                nxt_nos = tos; nxt_n2  = nos; `ifdef ENABLE_SPILL_STACK nxt_sp = sp + 1; `endif end // Pushes onto stack
         endcase

      end else if (grp == `BRANCH) begin
         if (z) begin
            nxt_pc = nos;
         end
      end
   end

   // ==========================================================
   // 7. CONCERN E: Flattened Sequential Storage
   // ==========================================================
   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         pc    <= 0;
         c_reg <= 0;
         tos   <= 8'hc;
         nos   <= 8'hb;
         n2    <= 8'ha;
         `ifdef ENABLE_SPILL_STACK
         sp    <= 0;
         `endif
      end else begin
         pc    <= nxt_pc;    
         c_reg <= nxt_c; 
         tos   <= nxt_tos;   
         nos   <= nxt_nos;

         `ifdef ENABLE_SPILL_STACK
         sp    <= nxt_sp;

         // Synchronous Read: Only access RAM when a true DROP group is active
         if (!is_lit && (grp == `ALU || grp == `REG) && grp[1]) begin
            n2 <= stack_mem[nxt_sp]; // Safe, back-to-back streaming pop read
         end else begin
            n2 <= nxt_n2;            // Keep normal combinatorial calculation
         end

         // Sync Write to LUT RAM on Stack Growth
         if (is_lit) begin
	    // PUSH
            stack_mem[sp] <= n2;
         end else if (grp == `STACK) begin
	    // SPILL
            if (sub_op == `OVER || sub_op == `DUP) begin
               stack_mem[sp] <= tos;
            end
         end
         `else
         n2    <= nxt_n2;
         `endif
      end
   end
endmodule
