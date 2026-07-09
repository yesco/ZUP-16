// --- VSIW Duality Master Architecture Definitions ---

// 32 instructions
// ===============

// REG:    ror  rol  asr         shr  shl  shr4 shl4
//  drop:   u    s    e    l      e    s    s    s
//  pc:
//  dpc:

// STK :   inv  rev  nop  dup    tuck rot  read writ
//  drop             drop swap   over nip  
//  pc:
//  dpc:


// ALU:   +=   -=   inc  dec     neg      
//  drop: add  sub                    and  or   xor
//  pc:
//  dpc:

// RST:   r>   rcpy for  >r                     true
//  pc:   jz   jn   next jsr                        
//  drop:  ?    ?    ?    ?
//  dpc:   ?    ?    ?    ?


`define STACK  2'b00
`define REG    2'b01
`define ALU    2'b10
`define RSTACK 2'b11

`define iSIGN   {"SIGN", {1'b1, `BITSY, `SIGN}}

`define iJZ   {"JZ  ", {1'b1, `BRANCH,  3'b000}}
`define iJNZ  {"JNZ ", {1'b1, `BRANCH2, 3'b000}}

// REG     4'b1100
// Register Ops (not moving stack)
`define INC  3'b000
`define DEC  3'b001
`define ROR  3'b010
`define ASR  3'b011
`define SHR  3'b100
`define SHR4 3'b101
`define SHL  3'b110
`define SHL4 3'b111

`define iINC  {"INC ", {1'b1, `REG, `INC}}
`define iDEC  {"DEC ", {1'b1, `REG, `DEC}}
`define iROR  {"ROR ", {1'b1, `REG, `ROR}}
`define iASR  {"ASR ", {1'b1, `REG, `ASR}}
`define iSHR  {"SHR ", {1'b1, `REG, `SHR}}
`define iSHR4 {"SHR4", {1'b1, `REG, `SHR4}}
`define iSHL  {"SHL ", {1'b1, `REG, `SHL}}
`define iSHL4 {"SHL4", {1'b1, `REG, `SHL4}}

// STACK
`define st0  3'b000
`define MUL  3'b001
`define NOP  3'b010
`define ROT  3'b011
`define SWAP 3'b100
`define OVER 3'b101
`define TUCK 3'b110
`define DUP  3'b111

`define ist0  {"st0 ", {1'b1, `STACK, `st0}}
`define iMUL  {"MUL ", {1'b1, `STACK, `MUL}}

`define iNOP  {"NOP ", {1'b1, `STACK, `NOP}}
`define iNOP  {"NOP ", {1'b1, `STACK, `NOP}}

`define iROT  {"ROT ", {1'b1, `STACK, `ROT}}
`define iSWAP {"SWAP", {1'b1, `STACK, `SWAP}}
`define iOVER {"OVER", {1'b1, `STACK, `OVER}}
`define iTUCK {"TUCK", {1'b1, `STACK, `TUCK}}
`define iDUP  {"DUP ", {1'b1, `STACK, `DUP}}

// ALU     4'b1110
// ALU Sub-instruction Opcodes
`define ADD  3'b000
`define ADC  3'b001
`define SUB  3'b010
`define SBC  3'b011
`define AND  3'b100
`define OR   3'b101
`define XOR  3'b110
`define DROP 3'b111

`define iADD  {"ADD ", {1'b1, `ALU,   `ADD}}
`define iADC  {"ADC ", {1'b1, `ALU,   `ADC}}
`define iSUB  {"SUB ", {1'b1, `ALU,   `SUB}}
`define iSBC  {"SBC ", {1'b1, `ALU,   `SBC}}
`define iAND  {"AND ", {1'b1, `ALU,   `AND}}
`define iOR   {"OR  ", {1'b1, `ALU,   `OR}}
`define iXOR  {"XOR ", {1'b1, `ALU,   `XOR}}
`define iDROP {"DROP", {1'b1, `ALU,   `DROP}}

// RSTACK  4'b1111

// #`define iLIT 8'b0????_???



// -- DROPPERS: (a b -> c)
8'b110??_000: T= t + n;     // + 
8'b110??_001: T= t & n;     // AND
8'b110??_010: T= t | n;     // OR
8'b110??_011: T= t ^ n;     // XOR
// 8'b?_110??_100: ram[t]= n;    // !    (value remain)
8'b110??_101: R= t;         // !R
// 8'b110??_110: PC= t;        // GOTO (Bit 4=1: Always jumps regardless of !n flag state)
// 8'b110??_111: PC= t;        // %BRANCH (Bit 4=0 AND !n=1: Conditional Jump executes)
8'b110??_110:
// 8'b110??_100: ;             // ZBRANCH (handle outside)
8'b110??_111:


// -- REGISTER: (a b -> c d)
8'b100??_000: T= ~t;        // INV
8'b100??_001: T= t<<1;      // SHL
8'b100??_010: T= t>>1;      // SHR
// 8'b101??_011: T= ram[t]     // @
8'b101??_111:

// -- PRODUCER: (a b -> c d e)
8'b101??_000: ;             // DUP
8'b101??_001: T= r;         // @R
// 8'b101??_000: T= n;         // OVER
// 8'b101??_000: N2= t;        // TUCK
8'b101??_010: T= pc;        // ???

// -- SPECIAL: 111_xx_xxx
