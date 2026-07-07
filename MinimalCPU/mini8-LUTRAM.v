// mini8.v: A mini8 stack cpu
//
// Editing: Only change lines if really needed, any other changes ask

`include "mini8_inc.v"

module mini8 (
              input wire       clk, 
              input wire       rst_n,
              output reg [7:0] pc,
              input wire [7:0] op,

              // External flag monitors
              output wire c,
              output wire z, 
              output wire neg,
              output wire v  
              );

   // ==========================================================
   // 1. Storage & Wire Aliases (The Background Map)
   // ==========================================================
   reg        c_reg;
   reg [7:0]  t, n, n2;

   wire [7:0] acc;
   wire       c_in;

   `ifdef DSTACK
   reg [4:0]  sp, SP;
   wire [7:0] ram_data_out;
   wire       write_en = (SP > sp);

   // Dual-Mode compilation path to handle Yosys limitations
   `ifdef SYNTHESIS
      // 1. Pure Hardware Primitive Path for Yosys Synthesis
      wire [4:0] ram_addr = write_en ? sp : SP;

      wire w_en_col0 = write_en && (~sp[4]);
      wire [7:0] r_data_col0;
      RAM16S4 ram_low_col0  (.CLK(clk), .WRE(w_en_col0), .AD(ram_addr[3:0]), .DI(n2[3:0]), .DO(r_data_col0[3:0]));
      RAM16S4 ram_high_col0 (.CLK(clk), .WRE(w_en_col0), .AD(ram_addr[3:0]), .DI(n2[7:4]), .DO(r_data_col0[7:4]));

      wire w_en_col1 = write_en && sp[4];
      wire [7:0] r_data_col1;
      RAM16S4 ram_low_col1  (.CLK(clk), .WRE(w_en_col1), .AD(ram_addr[3:0]), .DI(n2[3:0]), .DO(r_data_col1[3:0]));
      RAM16S4 ram_high_col1 (.CLK(clk), .WRE(w_en_col1), .AD(ram_addr[3:0]), .DI(n2[7:4]), .DO(r_data_col1[7:4]));

      assign ram_data_out = SP[4] ? r_data_col1 : r_data_col0;
   `else
      // 2. Pure Behavioral Array Path for Icarus Verilog Simulation
      reg [7:0] stack [0:31];
      assign ram_data_out = stack[SP];
      
      always @(posedge clk) begin
         if (write_en) begin
            stack[sp] <= n2;
         end
      end
   `endif
   `endif

   assign acc  = t;
   assign c_in = c_reg;

   assign c = c_reg;
   assign z = (t == 8'd0); 
   assign neg = t;
   assign v = 0;

   // Instruction Decoder Extraction
   wire       is_lit   = (op[7] == 0); // DON'T CHANGE: you keep messing it up!
   wire [6:0] lit_data = op[6:0];      
   
   wire [3:0] grp    = op[6:3];
   wire [2:0] sub_op = op[2:0];

   // Factored Next-State Stack Nets
   reg        C;    
   reg [7:0]  PC, T, N, N2;

   // --- Single-Adder Control Mux Nets ---
   reg        cin;
   reg [7:0]  a_mux, b_mux;

   // ==========================================================
   // 3. CONCERN A: Pure ALU Math & Stack Engine
   // ==========================================================
   always @(*) begin

      // Top-level initializations
      T  = t;
      N  = n;
      N2 = n2;
      C  = c_reg; 
      PC = pc + 1;

      `ifdef DSTACK
      SP = sp;
      `endif

      // Shared Operand Route Baseline Defaults
      cin   = 0;

      a_mux = n;
      b_mux = t;
      
      if (is_lit) begin

         // PUSH logic embedded directly + RAM Spill
         C = 0;
         T = {1'b0, lit_data};
         N = t;
         N2= n;

         `ifdef DSTACK
         SP  = sp + 1;
         `endif

      end else if (grp == `ALU || grp == `REG) begin

         // PASS 1: Set up the routing parameters for arithmetic operations
         case (sub_op)
           `ADD: begin b_mux = t;  cin = 0;      end
           `ADC: begin b_mux = t;  cin = c_reg;  end
           `SUB: begin b_mux = ~t; cin = 1;      end
           `SBC: begin b_mux = ~t; cin = ~c_reg; end
         endcase 

         if (grp == `REG) begin 

	    // TODO: if INC(+DEC) was ALU blocked, would it be chepaer?
            case (sub_op)
              `INC: begin b_mux = t; a_mux =  0;  cin = 1; end
              `DEC: begin b_mux = t; a_mux = ~0;  cin = 0; end
            endcase

         end

         // THE ONLY ARITHMETIC LINE
         {C, T} = a_mux + b_mux + cin;

         // PASS 2: Logical operations cleanly overwrite T if active
         if (grp[1]) begin // (this cheaply detects ALU)

            // DROP logic embedded directly
            N = n2;
            `ifdef DSTACK
            SP = sp - 1;
            `endif

            // N2 is bypassed here; handled cleanly at the clock edge below
            case (sub_op)
              `AND:  T = t & n;
              `OR :  T = t | n;
              `XOR:  T = t ^ n;
              `DROP: T = n;
            endcase

         end else if (sub_op[2]) begin

            case (sub_op)
	      `SHR:  begin T = t /  2; end 
	      `SHR4: begin T = t / 16; end
	      `SHL:  begin T = t *  2; end 
	      `SHL4: begin T = t * 16; end 
            endcase
            
	    // saves one LUT, lol
	    if (grp == `REG && sub_op[2])
	      C = sub_op[1] ? (sub_op[0] ? t[3] : t[7]) : (sub_op[0] ? t[4] : t[0]);

         end

      end else if (grp == `STACK) begin
         
         case (sub_op)
           `SWAP: begin T = n; N = t;                                            end
           `OVER: begin T = n; N = t; N2 = n; `ifdef DSTACK SP = sp + 1; `endif  end
           `DUP:  begin        N = t; N2 = n; `ifdef DSTACK SP = sp + 1; `endif  end
         endcase

      end else if (grp == `BRANCH) begin

         if (z) begin
            PC = n;
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
         t     <= 8'hc;
         n     <= 8'hb;
         n2    <= 8'ha;

         `ifdef DSTACK
         sp    <= 0;
         `endif

      end else begin

         pc    <= PC;    
         c_reg <= C; 
         t     <= T;   
         n     <= N;

         // -- ALL STACK UPDATES 
         `ifdef DSTACK

         sp    <= SP;

         // - Synchronous Read: Only access RAM when a true DROP group is active
         if (!is_lit && (grp == `ALU || grp == `REG) && grp[1]) begin
            
            // POP
            n2 <= ram_data_out;

         end else begin

            // Keep normal combinatorial calculation
            n2 <= N2;

         end
         `else

         // Just simply update if no deep SPILL stack
         n2    <= N2;

         `endif

      end
   end
endmodule
