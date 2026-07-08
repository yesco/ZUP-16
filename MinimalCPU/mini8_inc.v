// --- Master Global Architecture Definitions ---
`define BITSY   4'b0000
`define BITSY2  4'b0000
`define LOOP    4'b0010
`define LOOP2   4'b0011
`define JSRRET  4'b0100
`define JSRRET2 4'b0101
`define BRANCH  4'b0110
`define BRANCH2 4'b0111

`define READ    4'b1000
`define READ2   4'b1001
`define WRITE   4'b1010
`define WRITE2  4'b1011

`define REG     4'b1100
`define STACK   4'b1101
`define ALU     4'b1110
`define RSTACK  4'b1111


// --- Fused Mnemonic String + 8-Bit Opcode Macro Constants ---
// BITSY   4'b0000
// BITSY2  4'b0000
`define SIGN   3'b000
`define bit14  3'b001
`define bit13  3'b010
`define bit12  3'b011
`define bit11  3'b100
`define bit10  3'b101
`define bit09  3'b110
`define bit08  3'b111

`define bit07  3'b000
`define bit06  3'b001
`define bit05  3'b010
`define bit04  3'b011
`define bit03  3'b100
`define bit02  3'b101
`define bit01  3'b110
`define bit00  3'b111

`define iSIGN   {"SIGN", {1'b1, `BITSY, `SIGN}}
`define ibit14  {"bt14", {1'b1, `BITSY, `bit14}}
`define ibit13  {"bt13", {1'b1, `BITSY, `bit13}}
`define ibit12  {"bt12", {1'b1, `BITSY, `bit12}}
`define ibit11  {"bt11", {1'b1, `BITSY, `bit11}}
`define ibit10  {"bt10", {1'b1, `BITSY, `bit10}}
`define ibit09  {"bt09", {1'b1, `BITSY, `bit09}}
`define ibit08  {"bt08", {1'b1, `BITSY, `bit08}}

`define ibit07  {"bt07", {1'b1, `BITSY2, `bit07}}
`define ibit06  {"bt06", {1'b1, `BITSY2, `bit06}}
`define ibit05  {"bt05", {1'b1, `BITSY2, `bit05}}
`define ibit04  {"bt04", {1'b1, `BITSY2, `bit04}}
`define ibit03  {"bt03", {1'b1, `BITSY2, `bit03}}
`define ibit02  {"bt02", {1'b1, `BITSY2, `bit02}}
`define ibit01  {"bt01", {1'b1, `BITSY2, `bit01}}
`define ibit00  {"bt00", {1'b1, `BITSY2, `bit00}}

// LOOP    4'b0010
// LOOP2   4'b0011

// JSRRET  4'b0100
// JSRRET2 4'b0101

// BRANCH  4'b0110
// BRANCH2 4'b0111
`define iJZ   {"JZ  ", {1'b1, `BRANCH,  3'b000}}
`define iJNZ  {"JNZ ", {1'b1, `BRANCH2, 3'b000}}

`define READ    4'b1000
`define READ2   4'b1001
`define WRITE   4'b1010
`define WRITE2  4'b1011

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

`define iINC  {"INC ", {1'b1, `REG,   `INC}}
`define iDEC  {"DEC ", {1'b1, `REG,   `DEC}}
`define iROR  {"ROR ", {1'b1, `REG,   `ROR}}
`define iASR  {"ASR ", {1'b1, `REG,   `ASR}}
`define iSHR  {"SHR ", {1'b1, `REG,   `SHR}}
`define iSHR4 {"SHR4", {1'b1, `REG,   `SHR4}}
`define iSHL  {"SHL ", {1'b1, `REG,   `SHL}}
`define iSHL4 {"SHL4", {1'b1, `REG,   `SHL4}}

// STACK   4'b1101
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

