// --- BIW Duality Master Architecture Definitions ---

// Instruction Mask
// ====================================
// 00 xxx xxx   = 6 bit prefix constant builder { tos, xxxxxx }

// 01 0 iiiii   = no prefix: READfixed address slot[iiiii], prefix: slot[p6p i5i] slot[p6p p6p i5i]
//                0 read0-31: "overlong read" make it relative! slot[TOS + i5i] (saves one byte)

// 01 1 iiiii   = 32 "ALU" instructions


// 10 0 ooooo   = jnz forward 5 bits, w prefix: pc+= {tosbits o5o} onebit=SUPER CONDITION
// 10 1 ooooo   = always jmp

// 11 0 iiiii   = no prefix: jsr#0-31 subroutine vector jump PC=rstack[#], 1-2 prefix: see jmp (pinc=0)
// 11 0 11110   = FOR
// 11 0 11111   = TCALL

// 11 10 xxxx   = FREE! (any more control?)
// 11 10 0xxx   =   fr0-6 fpush
// 11 10 1xxx   =   fw0-6 fpop
// 11 11 xxxx   = 16 looping instructions ending with ret=FF


// FRAME POINTER
// -------------
// Used for C style function with parameter compilation.
// Provides a pointer into the stack and indexed access to local parameters
//
//       1 nop 2 nop 3 JSR#foo
//
// foo:  4 nop 5 fpush .... fr0 fr1 + fr2 + fr3 + fr4 + fret

// fpush: rpush(fp); fp <- sp;
// fpop : sp= fp; fp= rpop;


// SUPER CONDITION
// ---------------
// if hibit of prefix set; reinterpret condition bit

// 1 PREFIX:
//   0: nzif
//   1: oddif

// 2 PREFIX: 42 =if   OR   42 <if  ... 3 bytes ... but: dup 42 - jnz#xxx === 4-5 bytes
//   0: p6p == tos, then jump 
//   1: p6p <  tos, ...



//           (rev) ror  rol  asr    shr  shl  shr4 shl4

// ALU:       add  sub (inc)(dec)  (neg) and  or   xor       :: mostly droppers
//                      inc  dec                  (inv)      :: inv is free from ALU!

//            nop drop  mul  hash   bswp(inv) 0=   0<

//            rcpy r>   >r   rdrp   read writ sign true

// IO:        0 inc == IN0 == getchar, 0 dec == OUT0 putchar/puts
//            dec= decree! OUT1 == 16 bits "number" out


// Instructions where no prefix makes sense:
// -----------------------------------------
// (meaning can have other prefix triggered action)
//   drop dup over tuck rot nip shr4 shl4 ror rol asr rev
//       0= 0<
//   inc dec sign true neg byte inv bswp abs
//   rcpy >r r> rdrp
//   next loop <<lp =fnd  whil untl strd read stwr writ agin ret

// PREFIX ACTION
// =============
//   inc dec ::: we're going to use them w prefix for INP and OUT

TODO: update




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
`define JPOS  5'b11001
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
`define iJPOS  {"JPOS", {3'b111, `JPOS}}
`define iNEXT  {"NEXT", {3'b110, `NEXT}}
`define iCALL  {"CALL", {3'b111, `JSR}}

//`define iREV   {"REV ", {3'b100, `REV}}
//`define iABS   {"ABS ", {3'b100, `ABS}}

`define iSIGN  {"SIGN", {3'b100, `SIGN}}
`define iTRUE  {"TRUE", {3'b100, `TRUE}}

`define kJZ    {"JZ  ", {3'b110, `JZ}}
`define kJPOS  {"JPOS", {3'b110, `JPOS}}
`define dNEXT  {"NEXT", {3'b111, `NEXT}}
`define kCALL  {"CALL", {3'b110, `JSR}}


// --- Automated Simulation Mnemonic Decoder Subsystem ---
`ifndef SYNTHESIS
`define MAP(op) testbench.name[op & 255] = op >> 8

module biw_tb_helper;
initial begin: auto_mnemonic_init
   reg [23:0] auto_arg;
   integer auto_idx;

   // 1. Establish clear templates for literals
   for (auto_idx = 0; auto_idx < 128; auto_idx = auto_idx + 1) begin
      $sformat(auto_arg, " %02h ", auto_idx);
      testbench.name[auto_idx] = auto_arg;
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
   `MAP(`iJZ);    `MAP(`kJZ);    `MAP(`iJPOS);  `MAP(`kJPOS);
   `MAP(`iNEXT);  `MAP(`dNEXT);  `MAP(`iCALL);  `MAP(`kCALL);  
   `MAP(`iSIGN);  `MAP(`iTRUE);  //`MAP(`iREV);
end
endmodule
`endif // SYNTHESIS
