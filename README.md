# ZUP-16

ZUP-16: An FPGA Byte-Coded Single-Cycle Dual-Stack`16-bit CPU

# Instructions

```
=================================================================
ZUP-16 UNIFIED ISA ARCHITECTURE SPECIFICATION (COMPLETE & FROZEN)
=================================================================

Many instructions use prefixs to have different modes/instructions.
For a given number of prefixes, a fixed immediate bit value can be used.
  0 prefix : 0-4 bits; using inline operand or stack/register.
  1 prefix : 6-10 bits; local fixed address/index/relative.
  2 prefix : 12-16 bits; mostly absolute addressing

== [0x00 - 0x3F] : 64 PREFIX BUILD CONSTANTS (PFIX)
0x00..0x3F    : sh6lit# - Shifts 6 bits into TOS from right using xor;
   If builder flag zero then zero TOD first; set BUILDER flag.
   Count number of prefixes in sequence.
 NOTE: all other instructions clear the BUILDER flag; PREFIX COUNT=0
 WARNING: to put two constants on the stack use NOP to delimit them.
 

== [0x40 - 0x5F] : 16 READ/WRITES (write / barts)
0x40..0x4F    : READ: CASE prefix_count OF
0x50..0x5F    : WRTE: CASE prefix_count OF

    0 (1 Byte)  : REGISTER. Addresses global slots 0..15 directly.
                  Address = { 11'b000000000000, ir[3:0] }
    1 (2 Bytes) : 10 bits address read/write. Range 0-1023.
                  Address = { 0….0,   tos[5:0], ir[3:0] }
    2 (3 Bytes) : Absolute Far Write. Full 16-bit address.
                  Address = {   tos[11:0],      ir[3:0] }

  * SIGN BIT: WORD / BYTE ADDRESSING using indexed slots
      0 : WORD INDEX 15-bit hardware words. 64KB
      1 : BYTE INDEX 15-bit bytes.          32KB
    NOTE: bytes can only address half the memory (lower); baddr=waddr*2
   

== [0x60 - 0x6F] : 16 SUBROUTINES (jsr)
0x60..0x6F    : CASE prefix_count OF

    0 (1 Byte)  : Fast Vector JSR# (0-15) to Top of Memory, 8 byte slots,
                  Address = { 9'b111111111, ir[3:0], 3'b000 }
       SPECIAL VECTORS 
         0 : JSRTOS  - Jump SubRoutine to TOS. Method dispatch.
         1 : BEGIN   - Begin loop; inject PC+1 into R2, push old R2.
         i : USER#   - 2-15: USER DEFINED single byte code instructions!
        
    1 (2 Bytes) : Absolute Near JSR (Replaces lower 10 bits of PC).
                  Address = { PC[15:10], tos[5:0], ir[3:0] }

    2 (3 Bytes) : Absolute Far JSR (Full 16-bit address overwrite).
                  Address = {        tos[11:0]   , ir[3:0] }


== [0x70 - 0x7F] : 16 SPECIALISED STREAMING CONTROL FUNCTIONS
  These are highly specialized single byte loop control.
  They require the return stack to contain loopback address in R2,
  Control counter/search valuemin R. Set by BEGIN.

0x70..0x7F    : CASE prefix_count OF
     0 : LOOPING CONDITIONALS using return! - see section below
     1 :         : 6-10 bits imm data w 0-63 prefix! FUTURE INSTR?      
     2 : OF      : #=ifNjmp#n compare one prefix constant w nos, NE jmp

= 1 prefix
  0xxx           : 8 instructions FREE w 6-bit constant / 9 bits
  1000   STEP#   : R-= prefix!
  1xxx           : 7 FREE w 6-bit constant / 8.825 bits, lol

= No prefix
  0000   RET     : Unconditional return.
  0001   PUMP    : Pulls a single cell from (NOS) into TOS; advances NOS.
  0010   FLUSHn  : Writes a single cell from TOS out to (N2); advances N2.
  0011   ?SHR    : Conditional Shift Right. Clears bits / shifts TOS, increments tracking count in R. Popcoubt if P2==PC

  = LOOP BACK if TOS != R, otherwise continue.
  0100   =WAIT ? : Spinlock. Wait for TOS == R. For hardware IO flags?
  0101   =IN     : Streams from (NOS++) into TOS, until TOS == R.
  0110   =OUT  ? : Blasts TOS to (N2++), until a hardware flag matches R.
  0111   =STREAM : Pipelined copies (NOS> to (N2) until TOS == R.

  —- COUNTING OPERATORS (all counts R–)
  1000   STEP  ? :  Variable stride modifier. (R <= R - TOS).
  1001   IN      : Pulls a cell from (NOS++) to TOS, dec counter R.
  1010   OUT     : Writes TOS to N2, advances N2, dec counter R.
  1011   ?LINK   : The true pointer-chaser. NOS= (NOS++).

  = LOOP BACK if Dec R > 0, otherwise continue.
  1100   NEXT    : Traditional FOR loop, loops to R2 if R > 0.
  1101   ?IN     : Read in from (NOS++) to TOS, loops to R2.
  1110   ?OUT    : FILL. If R2==PC. Continuous single-cycle filler.
  1111   ?STREAM : Pipelined 1-cycle stream counted MOVE. If R2==PC.


== [0x80 - 0x9F] : 32 CONDITIONAL RETURNS/BRANCHES
{100 n ccdd}
  1 negation bit
  2 Bits Condition [Z Minus Carry Odd]
  2 Bits Displacement [-16  0 +16 +22]
  Effective address = <R[15:6]+displacement> <tos 6 bits>

0 prefix      : %ret      - jump Be ACK from JSR on condition.
1 prefix      : %branch   - window absolute jump if true.
2 prefix 80-8F: iread     - indexed read (addr+tos) => val.
         90-9F: iwrite    - write nos to (addr+tos) => nos.

% conditions:
0x80..0x83    : z*        - Jump If     Zero (Z)          
0x84..0x87    : c*        - Jump If     Carry (C)  
0x88..0x8B    : m*        - Jump If     Minus (Sign bit)       
0x8C..0x8F    : o*        - Jump If     Odd  (Lowest Bit) 
0x90..0x93    : nz*       - Jump If NOT Zero (NZ)    
0x94..0x97    : nc*       - Jump If NOT Carry (NC)  
0x98..0x9B    : p*        - Jump If NOT Minus (NS) = Positive (P)
0x9C..0x9F    : e*        - Jump If NOT Odd (Even) 


== [0xA0 - 0xDF] : 64 FRAME INDEXING OPERANDS (Fast-Path Block)
0xA0..0xAE    : fread#      0..14 : Reads slot (FR + index) to TOS.
0XAF          : fread             : -”-, index=TOS or prefix 1-2 bytes.
0xB0..0xBE    : fwrite#     0..14 : Copy & keep TOS to slot (FR + index).
0XAF          : fread             : -”-, index=TOS or prefix 1-2 bytes.
0xC0..0xC7    : fread#dec   0.. 7 : Reads slot. Push val-1
0xC8..0xCF    : fread#inc   0.. 7 : Reads slot. Push val+1
0xD0..0xD7    : fshr#       0.. 7 : Reads slot. Push shr, spills to C.
0xD8..0xDF    : fshl#       0.. 7 : Reads slot. Push shl, spills to C.


== [0xE0 - 0xEF] : 16 REGISTER MANIPULATION & STACK SHORTCUTS (Ode to 6502 Mapping)
0xE0          : inc      - Increment TOS by 1.
0xE1          : dec      - Decrement TOS by 1.
0xE2          : ror      - Rotate C into TOS right by 1 bit. Spill to C.
0xE3          : asr      - Arithmetic shift TOS right 1 bit; spill to C.
0xE4          : shr      - Shift TOS right by 1 bit; spill to Carry.
0xE5          : shr4     - Shift TOS right by 4 bits (Nibble shift); C.
0xE6          : shl      - Shift TOS left by 1 bit; spill to C.
0xE7          : shl4     - Shift TOS left by 4 bits (Nibble shift); C.

0xE8          : rand  ?  - Randomization by gaussian.
0xE9          : mul      - Multiply16x16=> TOS=High 16-bits, NOS=Low.
0xEA          : nop      - No Operation; clears LIT_ACTIVE flag (6502).
0xEB          : rot      - Rotate three values. (-rot==rot rot)
0xEC          : swap     - Exchange the positions of TOS and NOS.
0xED          : over     - Copy NOS to the top of the stack.
0xEE          : tuck     - Insert a copy of TOS underneath NOS.
0xEF          : dup      - Duplicate TOS.


==][0xF0 - 0xF7] : 8 MATH & LOGIC ALU CORE INSTRUCTIONS (a b -> c)
0xF0          : add     - C; Push (NOS + TOS) to stack.
0xF1          : adc     - C; Push (NOS + TOS + C). (negate==-1 xor inc)
0xF2          : sub     - C; Push (NOS - TOS). C=!borrow (sbc==adc sbc)
0xF3          : fma  ?  - Fused Multiply-Add Step.
0xF4          : and     - Push (NOS bitwise AND TOS).
0xF5          : or      - Push (NOS bitwise OR TOS).
0xF6          : xor     - Push (NOS bitwise XOR TOS). (not==-1 xor)
0xF7          : drop    - Remove TOS.

== [0xF8 - 0xFF] : 8 RETURN STACK, MOSTLY
0xF8          : r>      - Move R to TOS. F same.
0xF9          : >r      - Move TOS to Return Stack.
0xFA          : rcopy   - Copy R to Data Stack (TOS).
0xFB          : fcopy   - Drop R. Push frame on data stack.
0xFC          : fset    - Frame register set.
0xFD          : bswap   - Swaps bytes.
0xFE          : sign    - Flips sign bit.
0xFF          : -1      - Minus one, aka True.
===============================================
```