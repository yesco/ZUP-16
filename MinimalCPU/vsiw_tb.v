// mini8_tb.v: A "terminaL' for mini8
//
// Editing: Only change lines if really needed, any other changes ask

`timescale 1ns/1ps

`define MAP(op) name[op & 255] = op >> 8

// --- NEW: Fused Auto-Increment Program Loader Macro ---
`define PROM(val) bram[wraddr] = val; wraddr = wraddr + 1

module mini8_tb;
   reg clk;
   reg rst_n;
   
   reg  [7:0] bram[0:255]; 
   
   // --- Synchronous Dual-Port BRAM Logic ---
   reg  [7:0] mem_rdata_a_reg;
   reg  [7:0] mem_rdata_b_reg;
   
   wire       mem_en_a;
   wire [7:0] mem_addr_a;
   wire       mem_en_b;
   wire       mem_we_b;
   wire [7:0] mem_addr_b;
   wire [7:0] mem_wdata_b;

   always @(posedge clk) begin
      if (mem_en_a) begin
         mem_rdata_a_reg <= bram[mem_addr_a];
      end
      if (mem_en_b) begin
         if (mem_we_b) begin
            bram[mem_addr_b] <= mem_wdata_b;
         end
         mem_rdata_b_reg <= bram[mem_addr_b];
      end
   end

   // Direct combinatorial wire path feeds the arriving next instruction
   wire [7:0] op = mem_rdata_a_reg;

   reg  [31:0] name[0:255];
   wire [31:0] mnemonic = name[cpu.op];

   vsiw cpu (
             .clk(clk),
             .rst_n(rst_n),
             .op(op),
             .mem_en_a(mem_en_a),
             .mem_addr_a(mem_addr_a),
             .mem_rdata_a(mem_rdata_a_reg),
             .mem_en_b(mem_en_b),
             .mem_we_b(mem_we_b),
             .mem_addr_b(mem_addr_b),
             .mem_wdata_b(mem_wdata_b),
             .mem_rdata_b(mem_rdata_b_reg)
             );

//   always #10 clk = ~clk;

   always #7 clk = ~clk;

// TODO: shorter works better for FOR...NEXT loop!
//   always #5 clk = ~clk;

   reg [23:0] arg;

`define DSTACK
   
`ifdef DSTACK
   wire [7:0] S3;
   wire [7:0] S4;
   wire [7:0] S5;

   assign S3 = cpu.stack[cpu.sp - 5'd1];
   assign S4 = cpu.stack[cpu.sp - 5'd2];
   assign S5 = cpu.stack[cpu.sp - 5'd3];
`endif
   
   // Track the write index location sequentially
   integer wraddr;
 
   initial begin
      // Fast flat clears
      for (integer i = 0; i < 256; i = i + 1) begin
         bram[i] = 8'h00;
         name[i] = "--- ";
      end
      
      // Initialize the pointer base address
      wraddr = 0;

      // --- Program Array Assembly Space (No Manual Indices needed!) ---
`ifndef iADC
 `define iADC `iADD
`endif
      
`ifdef FISH
      `PROM(7);        
      `PROM(`iNOP);
      `PROM(5);        
      `PROM(`iNOP);
      `PROM(3);        
      `PROM(`iADD);    
      `PROM(`iADD);    
      `PROM(`iSWAP);   
      `PROM(`iSWAP);   
      `PROM(`iDUP);    
      `PROM(`iDROP);   
      `PROM(0);        
      `PROM(`iNOP);
      `PROM(1);        
      `PROM(`iSUB);    
      `PROM(1);        
      `PROM(`iADC);    
      `PROM(1);        
      `PROM(`iNOP);
      `PROM(2);        
      `PROM(`iNOP);
      `PROM(3);        
      `PROM(`iOVER);   
      `PROM(1);        
      `PROM(`iNOP);
      `PROM(2);        
      `PROM(`iNOP);
      `PROM(3);        
      `PROM(`iTUCK);
      `PROM(`iROT);    
      `PROM(`iINC);
      `PROM(`iINC);
      `PROM(`iINC);
      `PROM(`iDEC);
      `PROM(`iDEC);
      `PROM(`iDEC);
      `PROM(8'b01101101);
      `PROM(`iSHL);
      `PROM(`iSHL);
      `PROM(`iSHR);
      `PROM(`iSHR);
      
      `PROM(63);
      `PROM(`iNOP);
      `PROM(63);
      `PROM(`iNOP);
      `PROM(63);
      `PROM(`iNOP);

      `PROM(1);
      `PROM(`iNOP);
      `PROM(2);
      `PROM(`iNOP);
      `PROM(3);
      `PROM(`iNOP);
      `PROM(4);
      `PROM(`iNOP);
      `PROM(5);
      `PROM(`iNOP);
      `PROM(6);
      `PROM(`iNOP);
      `PROM(7);
      `PROM(`iNOP);
      `PROM(8);
      `PROM(`iDROP);
      `PROM(`iDROP);
      `PROM(`iDROP);
      `PROM(`iDROP);
      `PROM(`iDROP);
      `PROM(`iDROP);
      `PROM(`iDROP);
      `PROM(`iDROP);
`endif

      `PROM(8'h42);
      `PROM(`iNOP);
      

      `PROM(17);
      `PROM(`iNOP);
      `PROM(`iTOR); // BUG: need two!!!

      `PROM(`iFOR);
      `PROM(`iNEXT);
      `PROM(`iNOP); 
      `PROM(`iNOP); 
      `PROM(`iNOP); 
      `PROM(`iNOP); 
      
      `PROM(`iDROP);

      // ==========================================
      // --- COUNTDOWN LOOP WITH DYNAMIC LABEL ---
      // ==========================================
      `PROM(9);         // TOS = 3 (Our loop counter)
      `PROM(`iNOP);
      
      // Capture the exact memory address dynamically right here
      
      begin: loop
	 integer loop_start;

	 `PROM(`iNOP);

	 loop_start = wraddr;

	 `PROM(`iDEC);

	 `PROM(loop_start);  // Load the dynamically captured loop start address
	 `PROM(`iJPOS);      // Fused jump if counter == 0

      end
      `PROM(`iDROP); // Clean up counter if loop falls through


      
`ifdef DSTACK
      $display("-----------------------------------------------------------");
      $display(" TIME  | PC | OP | Z C N V | -5 -4 -3 | N2 N  T  | R  R2");
      $display("-----------------------------------------------------------");
      
      $monitor("%6d | %02h |%s %b| %b %b %b %b | %02h %02h %02h | %02h %02h %02h | %02h %02h",
               $time, cpu.pc, mnemonic, cpu.op, cpu.z, cpu.c, cpu.neg, cpu.v,
               S5, S4, S3, cpu.n2, cpu.n, cpu.t,
	       cpu.r, cpu.r2);

`else
      $display("--------------------------------------------------");
      $display(" TIME  | PC | OP | Z C N V | N2 N  T  | R  R2");
      $display("---------------------------------------------------");
      
      $monitor("%6d | %02h |%s| %b %b %b %b | %02h %02h %02h | %02h %02h",
               $time, cpu.pc, mnemonic, cpu.z, cpu.c, cpu.neg, cpu.v,
               cpu.n2, cpu.n, cpu.t_reg, cpu.r, cpu.r2);
`endif
      
      clk = 0;
      rst_n = 0;
      #25;
      rst_n = 1; 

      #3000;
      $display("--------------------------------------------");
      $finish; 
   end
endmodule
