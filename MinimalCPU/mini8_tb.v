// mini8_tb.v: A "terminaL' for mini8
//
// Editing: Only change lines if really needed, any other changes ask

`timescale 1ns/1ps

`define MAP(op) name[op & 255] = op >> 8

// --- NEW: Fused Auto-Increment Program Loader Macro ---
`define PROM(val) rom[wraddr] = val; wraddr = wraddr + 1

module mini8_tb;
   reg clk;
   reg rst_n;
   
   reg  [7:0] rom[0:255]; 
   wire [7:0] op = rom[cpu.pc];

   reg  [31:0] name[0:255];
   wire [31:0] mnemonic = name[cpu.op];

   mini8 cpu (
              .clk(clk),
              .rst_n(rst_n),
              .op(op)
              );

   always #10 clk = ~clk;

   reg [23:0] arg;

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
         rom[i] = 8'h00;
         name[i] = "--- ";
      end
      
      // Initialize the LIT #09-ff
      for (integer i = 0; i < 128; i = i + 1) begin
         $sformat(arg, " %02h ", i);
         name[i] = arg;
      end
      

      // --- Single-Line Fused Mnemonic Decoder Mapping Table ---
      `MAP(`iSIGN);  `MAP(`ibit14); `MAP(`ibit13); `MAP(`ibit12);
      `MAP(`ibit11); `MAP(`ibit10); `MAP(`ibit09); `MAP(`ibit08);
      `MAP(`ibit07); `MAP(`ibit06); `MAP(`ibit05); `MAP(`ibit04);
      `MAP(`ibit03); `MAP(`ibit02); `MAP(`ibit01); `MAP(`ibit00);

      `MAP(`iJZ);   `MAP(`iJNZ);

      // - 32 OPS BLCOK

      `MAP(`iINC);   `MAP(`iDEC);   `MAP(`iROR);   `MAP(`iASR);
      `MAP(`iSHR);   `MAP(`iSHR4);  `MAP(`iSHL);   `MAP(`iSHL4);

      `MAP(`iADD);   `MAP(`iADC);   `MAP(`iSUB);   `MAP(`iSBC);
      `MAP(`iAND);   `MAP(`iOR);    `MAP(`iXOR);   `MAP(`iDROP);

      `MAP(`iSWAP);  `MAP(`iOVER);  `MAP(`iTUCK);  `MAP(`iDUP);
      `MAP(`iROT);   `MAP(`iNOP);   `MAP(`iMUL);   `MAP(`ist0);

      // TODO: RSTACK

      // Initialize the pointer base address
      wraddr = 0;

      // --- Program Array Assembly Space (No Manual Indices needed!) ---
      `PROM(7);        
      `PROM(5);        
      `PROM(3);        
      `PROM(`iADD);    
      `PROM(`iADD);    
      `PROM(`iSWAP);   
      `PROM(`iSWAP);   
      `PROM(`iDUP);    
      `PROM(`iDROP);   
      `PROM(0);        
      `PROM(1);        
      `PROM(`iSUB);    
      `PROM(1);        
      `PROM(`iADC);    
      `PROM(1);        
      `PROM(2);        
      `PROM(3);        
      `PROM(`iOVER);   
      `PROM(1);        
      `PROM(2);        
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
      `PROM(63);
      `PROM(63);

      `PROM(1);
      `PROM(2);
      `PROM(3);
      `PROM(4);
      `PROM(5);
      `PROM(6);
      `PROM(7);
      `PROM(8);
      `PROM(`iDROP);
      `PROM(`iDROP);
      `PROM(`iDROP);
      `PROM(`iDROP);
      `PROM(`iDROP);
      `PROM(`iDROP);
      `PROM(`iDROP);
      `PROM(`iDROP);
      
      
`ifdef DSTACK
      $display("--------------------------------------------------");
      $display(" TIME  | PC | OP | Z C N V | -5 -4 -3 | N2 NOS TOS");
      $display("---------------------------------------------------");
      
      $monitor("%6d | %02h |%s| %b %b %b %b | %02h %02h %02h | %02h %02h %02h",
               $time, cpu.pc, mnemonic, cpu.z, cpu.c, cpu.neg, cpu.v,
               S5, S4, S3, cpu.n2, cpu.n, cpu.t);
`else
      $display("--------------------------------------------------");
      $display(" TIME  | PC | OP | Z C N V | N2 NOS TOS");
      $display("---------------------------------------------------");
      
      $monitor("%6d | %02h |%s| %b %b %b %b | %02h %02h %02h",
               $time, cpu.pc, mnemonic, cpu.z, cpu.c, cpu.neg, cpu.v,
               cpu.n2, cpu.n, cpu.t);
`endif
      
      clk = 0;
      rst_n = 0;
      #25;
      rst_n = 1; 

      #1200; 
      $display("--------------------------------------------");
      $finish; 
   end
endmodule
