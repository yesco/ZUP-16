// --- VSIW Duality Master Architecture Definitions ---

// 32 instructions
// ===============
// All instructions basically exists in 4 variants:

// PCbit DROPbit  DESCRIPTION
//   0     0      keep value
//   0     1      drop one value
//   1     x      do same but at same time do RETURN

// Specific stack instruction behave different:
//   0     x      dup  / swap
//   0     x      tuck / over
//   0     x      rot  / nip

// Return stacuk (R) instructions change behavior
//   x     -      r>    / jz
//   x     -      rcopy / jn 
//   x     -      for   / next
//   x     -      >r    / call

// Numbering
//
//      (apparently moving xxx to first pos costs +16 LUT!)
//---     0:   ror  rol  asr  xxx     shr  shl  shr4 shl4

//---     8:   read writ nop  dup     over rot  inv  zero
//    32+ 8:             drop swap    tuck nip  

//---    16:   +=   -=   inc  dec     neg      
//    32+16:   add  sub                    and  or   xor

//---    24:   r>   rcpy for  >r      rev  abs  sign true
// 64+   24:   jz   jn   next jsr
// 64+32+24:   

// --- 5-Bit Base Instruction Encodings ---

// Row 0: Registers & Shifters (0 to 7)
`define ROR   5'b00000
`define ROL   5'b00001
`define ASR   5'b00010
`define XXX   5'b00011
`define SHR   5'b00100
`define SHL   5'b00101
`define SHR4  5'b00110
`define SHL4  5'b00111

// Row 1: Pure Stack Manipulators (8 to 15)
`define READ  5'b01000
`define WRIT  5'b01001
`define NOP   5'b01010
`define DUP   5'b01011
`define OVER  5'b01100

// TODO: remove?
`define TUCK  5'b01100

`define ROT   5'b01101
`define INV   5'b01110

`define REV   5'b11111
//`define ZRO   5'b01111

// Row 2: Arithmetic & Logical Core (16 to 23)
`define ADD   5'b10000
`define SUB   5'b10001
`define INC   5'b10010
`define DEC   5'b10011
`define NEG   5'b10100
`define AND   5'b10101
`define OR    5'b10110
`define XOR   5'b10111

// Row 3: Return Stack
`define RTO   5'b11000
`define RCPY  5'b11001
`define FOR   5'b11010
`define TOR   5'b11011

//      PC - value
`define JZ    5'b11000
`define JN    5'b11001
`define NEXT  5'b11010
`define JSR   5'b11011

//`define REV   5'b11100
//`define ABS   5'b11101

`define SIGN  5'b11110
`define TRUE  5'b11111


// --- 8-Bit Fused Instruction Composite Bytes ---

// Row 0 Fused Primitives (is_instr=1, pc_bit=0, drop_bit=0)
`define iROR   {"ROR ", {3'b100, `ROR}}
`define iROL   {"ROL ", {3'b100, `ROL}}
`define iASR   {"ASR ", {3'b100, `ASR}}
`define iXXX   {"XXX ", {3'b100, `XXX}}
`define iSHR   {"SHR ", {3'b100, `SHR}}
`define iSHL   {"SHL ", {3'b100, `SHL}}
`define iSHR4  {"SHR4", {3'b100, `SHR4}}
`define iSHL4  {"SHL4", {3'b100, `SHL4}}

// Row 1: Stack Primitives &  Bits & IO
`define iREAD  {"READ", {3'b100, `READ}}
`define iWRIT  {"WRIT", {3'b100, `WRIT}}

`define iNOP   {"NOP ", {3'b100, `NOP}}
`define iDROP  {"DROP", {3'b101, `NOP}}
`define iDUP   {"DUP ", {3'b100, `DUP}}
`define iSWAP  {"SWAP", {3'b101, `DUP}}
`define iTUCK  {"TUCK", {3'b100, `OVER}}
`define iOVER  {"OVER", {3'b101, `OVER}}
`define iROT   {"ROT ", {3'b100, `ROT}}
`define iNIP   {"NIP ", {3'b101, `ROT}}

`define iINV   {"INV ", {3'b100, `INV}}
//`define iZERO  {"ZERO", {3'b100, `ZRO}}

// Row 2: ALU primitives
`define kADD   {"+=  ", {3'b100, `ADD}}
`define kSUB   {"-=  ", {3'b100, `SUB}}

`define iADD   {"ADD ", {3'b101, `ADD}}
`define iSUB   {"SUB ", {3'b101, `SUB}}
`define iINC   {"INC ", {3'b100, `INC}}
`define iDEC   {"DEC ", {3'b100, `DEC}}
`define iNEG   {"NEG ", {3'b100, `NEG}}
`define iAND   {"AND ", {3'b101, `AND}}
`define iOR    {"OR  ", {3'b101, `OR}}
`define iXOR   {"XOR ", {3'b101, `XOR}}

// Group 3: Return Stack & Control Structures

`define iRTO   {"R>  ", {3'b100, `RTO}}
`define iRCPY  {"RCPY", {3'b100, `RCPY}}
`define iFOR   {"FOR ", {3'b100, `FOR}}
`define iTOR   {">R  ", {3'b101, `TOR}}


`define iJZ    {"JZ  ", {3'b111, `JZ}}
`define iJN    {"JN  ", {3'b111, `JN}}
`define iNEXT  {"NEXT", {3'b110, `NEXT}}
`define iCALL  {"CALL", {3'b111, `JSR}}

//`define iREV   {"REV ", {3'b100, `REV}}
//`define iABS   {"ABS ", {3'b100, `ABS}}

`define iSIGN  {"SIGN", {3'b100, `SIGN}}
`define iTRUE  {"TRUE", {3'b100, `TRUE}}

`define kJZ    {"JZ  ", {3'b110, `JZ}}
`define kJN    {"JN  ", {3'b110, `JN}}
`define dNEXT  {"NEXT", {3'b111, `NEXT}}
`define kCALL  {"CALL", {3'b110, `JSR}}


// --- Automated Simulation Mnemonic Decoder Subsystem ---
`ifndef SYNTHESIS
`define MAP(op) mini8_tb.name[op & 255] = op >> 8

module vsiw_tb_helper;
initial begin: auto_mnemonic_init
   reg [23:0] auto_arg;
   integer auto_idx;

   // 1. Establish clear templates for literals
   for (auto_idx = 0; auto_idx < 128; auto_idx = auto_idx + 1) begin
      $sformat(auto_arg, " %02h ", auto_idx);
      mini8_tb.name[auto_idx] = auto_arg;
   end

   // 2. Perform automated system mappings (Sorted by 5-bit Base Opcode Order)
   // Row 0: Registers & Shifters (0 to 7)
   `MAP(`iROR);   `MAP(`iROL);   `MAP(`iASR);   `MAP(`iXXX);   
   `MAP(`iSHR);   `MAP(`iSHL);   `MAP(`iSHR4);  `MAP(`iSHL4);  

   // Row 1: Pure Stack Manipulators (8 to 15)
   `MAP(`iREAD);  `MAP(`iWRIT);  `MAP(`iNOP);   `MAP(`iDROP);  
   `MAP(`iDUP);   `MAP(`iSWAP);  `MAP(`iOVER);  `MAP(`iTUCK);  
   `MAP(`iROT);   `MAP(`iNIP);   `MAP(`iINV);   //`MAP(`iZERO);  

   // Row 2: Arithmetic & Logical Core (16 to 23)
   `MAP(`kADD);   `MAP(`iADD);   `MAP(`kSUB);   `MAP(`iSUB);   
   `MAP(`iINC);   `MAP(`iDEC);   `MAP(`iNEG);   `MAP(`iAND);   
   `MAP(`iOR);    `MAP(`iXOR);   

   // Row 3: Return Stack & Program Control (24 to 31)
   `MAP(`iRTO);   `MAP(`iRCPY);  `MAP(`iFOR);   `MAP(`iTOR);   
   `MAP(`iJZ);    `MAP(`kJZ);    `MAP(`iJN);    `MAP(`kJN);    
   `MAP(`iNEXT);  `MAP(`dNEXT);  `MAP(`iCALL);  `MAP(`kCALL);  
   `MAP(`iSIGN);  `MAP(`iTRUE);  //`MAP(`iREV);
end
endmodule
`endif // SYNTHESIS
