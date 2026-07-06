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
   
   reg [7:0] rom[0:255]; 
   wire [7:0] op = rom[cpu.pc];

   reg [31:0] name[0:255];
   wire [31:0] mnemonic = name[cpu.op];

   mini8 cpu (
              .clk(clk),
              .rst_n(rst_n),
              .op(op)
              );

   always #10 clk = ~clk;

   reg [23:0] arg;

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
      `MAP(`iADD);  `MAP(`iADC);  `MAP(`iSUB);  `MAP(`iSBC);
      `MAP(`iAND);  `MAP(`iOR);   `MAP(`iXOR);  `MAP(`iDROP);

      `MAP(`iSWAP); `MAP(`iOVER); `MAP(`iTUCK); `MAP(`iDUP);
      `MAP(`iROT);  `MAP(`iNOP);  `MAP(`iMUL);  `MAP(`ist0);

      `MAP(`iINC);  `MAP(`iDEC);  `MAP(`iROR);  `MAP(`iASR);
      `MAP(`iSHR);  `MAP(`iSHR4); `MAP(`iSHL);  `MAP(`iSHL4);

      `MAP(`iSIGN); `MAP(`ibit14); `MAP(`ibit13); `MAP(`ibit12);
      `MAP(`ibit11); `MAP(`ibit10); `MAP(`ibit09); `MAP(`ibit08);
      `MAP(`ibit07); `MAP(`ibit06); `MAP(`ibit05); `MAP(`ibit04);
      `MAP(`ibit03); `MAP(`ibit02); `MAP(`ibit01); `MAP(`ibit00);

      `MAP(`iJZ);   `MAP(`iJNZ);

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
      
      $display("------------------------------------------");
      $display(" TIME  | PC | OP | Z C N V N2 NOS TOS");
      $display("------------------------------------------");
      
      $monitor("%6d | %02h |%s| %b %b %b %b  %02h %02h %02h",
               $time, cpu.pc, mnemonic, cpu.z, cpu.c, cpu.n, cpu.v,
               cpu.n2, cpu.nos, cpu.tos);

      clk = 0;
      rst_n = 0;
      #25;
      rst_n = 1; 

      #800; 
      $display("--------------------------------------------");
      $finish; 
   end
endmodule
