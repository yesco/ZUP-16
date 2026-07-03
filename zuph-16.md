ZUPH-16 Zero Utility Processor: Hashing Optimized Prefix Instruction Set Computer - ZUPHOPISC
=============================================================================================

Ztack Unicorn Processor (?)

Byte-coded dual-stack-machine intended to be implementd on FPGA Tang nano 20K.

16-bit (extensible to 64), pure single-byte, single-cycle instruction flow,
using flexible 7-bit-prefix-encoding sliding in literals into instructions.

Thus an instruction may have a literal-load first, and depending on
number of prefixes can perform slightly different tasks.

OP-code space divided into two halves; first for building literal numbers
7-bits at a time; and second for: bits+alu+stackops, control-flow,
memory, hashing. 


Unusualies
==========

ZUP has tried to take an untradition approach to a Forth-style CPU
than the J1 FPGA-implementation, for examploe. Instead of 16-bit VLIW,
that eases instruction decoding, we have a efficient but very hiearchical
instruction space achieving almost equal benefits. Because J1 decodes
instructions and then performs memory in practice it seems to have 2-cycle
erad and writes (?). ZUP avoids this using a by-pass, and should operate lightly
below double speed.

Many operations use an inline 4-bit literal argument. With this, slot-reading
and writing using a frame-pointer, or other register source gives single-byte,
single-cycle access.

Conditional jumps are extendeded to returns. Returns are mere single-byte
jumps pulling from the return-stack. Jumps are efficiently encoded as sliding-
window slot-in bit-replacing simple routing - avoiding costly full-adders.

Combined equal-test-and-jump are encoded for maximum utilty, allowing for
fast switch-case implementations.

In addition, specific looping constructs have been added, these are
super-power single instructions counting/comparing auto-streamers.
Ultimately,if the loopback is to the same instruction, a single-cycle
pipe-lined copy operation is realized. Likewise for double stream compare,
cycle-delays, bit-normalizations and -counting, as well as byte-searches.
Ultimately costing one cycle per step.

Larger literal arguments to instructions are built in TOS on the stack.
This takes 1 cycle per byte. Thus a 16-bit operation may need 3 cycles.
This may however be optimized by peep-holed execution, at slight extra
cost.

It is recognized that compilers might need be slightly more intelligent
than typical; merging (constant-)test-and-jmp or -returns into simple
efficient super instructions. But these represent highly-recognized and
repetetive patterns in both generated code as well as typical hand-written
Forth code.

It is the hope of the author that this experimental compact byte-code
machine might prove useful for embedded systems as well as sipmlify
compilation even for non-stack languages by providing powerful, compact
often used stack/frame/object operations.


Statistics
----------

Preliminary analysis of static byte-code codebases indicate the match:

- BYTES% (CYCLE%) ACTION
- 35-50% ( 5-10%) local frame accesses
- 15-35% (......) constants/addresses/literals
- 10-20% (35-45%) of instructions are control flow related (jsr/jmp/methods/ret)
- 10-18% (25-35%) memory accesses
- 10-15% (    5%) misc
-  8-15% (10-15%) arithmetic/register manipulations
- lower hanging items:
-  2- 4% ( 1- 2%) type casting/conversions (float2int promotef64 checkcast relevant for JVM)
-   < 1% ( 5-10%) exception handling
-  0- 2% (15-30%) synchronization/atomnics, multi-core

(Note: byte ranges are widened covering both static & dynamic codes)

It is believed that our ISA achieves: [Total Byte Footprint]
- Local Frame Access (LOAD0-15) [25%]
- Fused Literals/Addresses      [12%]
- Control Flow (Jumps/Sub)      [18%]
- Streaming/Super-Inst          [20%]
- Stack/Arithmetic/Misc         [25%]




------------ OVERVIEW


Bits      Pre  Mnemonic   Description

0 iiiiiii  -    LIT#       Accumulate 7-bit literal; if prefix_count=0 push new, else shift TOS left 7 and XOR inject

(each grouping 32 instructions:)

100 0iiii  -    TOGGLE/POW Toggle bit (15 - iiii) of TOS; old bit moves to carry register
100 1iiii  -    LOOP       Looping and Streaming Instructions

101 0iiii  -    JSR        Jump SubRoutine
101 1ncca  -    RET/BRANCH Conditional Branch and Return

110 0iiii  -    READ       Read memory
110 1iiii  -    WRITE      Write memory

111 00iii  -    -          ALU
111 01iii  -    -          stack
111 10iii  -    -          rstack
111 11iii  -               FREE
111 11110  ?    HASH       Hashing/Crypto/Extended Math related ops
111 11111  -    TRUE       Push -1; if prefix_count > 0, shift TOS left 7 and XOR invert full register contents



------------ DETAILS

Bits      Pre  Mnemonic   Description

128:

0iiiiiii  -    LIT#       Accumulate 7-bit literal; if prefix_count=0 push new, else shift TOS left 7 and XOR inject
11111111  -    TRUE       Push -1; if prefix_count > 0, shift TOS left 7 and XOR invert full register contents


16:

10000000  -    SIGN       Toggle SIGN bit of TOS; old bit moves to carry register
1000iiii  -    TOGGLE#    Toggle bit (15 - iiii) of TOS; old bit moves to carry register
10000000  1    POW        1>>TOS (modifies instruction decoding from data)
10000001  1    CSET       Set bit (15 - iiii) TOS of NOS equal to current carry register value
1000iiii  1    -          prefix FREE 2-15


16:

1001xxxx  0    LOOPS      TODO: Loops and Streams TODO: see prev design


16:

10100000  0    CALL       Calls subroutin in TOS (method dispatch) (Forth: EXEC)
10100001  0    BEGIN      Begin a loop; Push PC+1 into rstack below R!
1010iiii  0    JSR#       Jump SubRoutine 2-15, 1 cycle, 1 byte custom user routines

1010wwii  1    JSR#       Jump SubRoutine window address= replace bits {ww+1 bits if 0, prefix, ii, 000}
1010ccii  2    JSR#       Jump SubRoutine absolute 16-bit={14-bit 2 prefix, ii}
    00       Always
    01       NZ
    10       DUP-JSR
    11       FJSR         Frame Jump SubRoutine Push: push(fp); fp= sp; rpush(pc); pc= new;

FJSR who clean up the stack?
    

16:

1011cccc  0    %RET       Conditional Return w single optional Action (nip? or 0ret drop0ret)
    0000       RET        Uncondition Return
    0001       NIP-RET    Keep TOS, NIP one value, Return TOS
    0010       DROP-RET   Disguard TOS, Return "nos"
    0011       DROP-0-RET Disguard TOS, Return 0

    0100       CRET       Return on Carry
    0101       NCRET      Return no No Carry
    0110       EVENRET       
    0111       ODDRET

    1000       ZRET       Return on Zero  (keep) => 0
    1010       ZDROP-RET                  (drop) => nos "nip"?
    1001       NZRET      Return if NZero (keep) "HAVE-RET"
    1011       NZDROP-RET Return if NZero (drop) "IGNORE-RET"


 (these may not be possible as they reset stack so NOS=??? TOS can keep as return value:)
 (possibly look into some ObjectRET instead? FP= pop)
    1100       FRET       Frame Return: sp= fp; fp= stack[fp]; pc= rpop; keep TOS, NOS??? impossible
    1110       ZFRET      Frame Return on Zero stack[fp]
    1111       F-0-RET    Return 0, Frame        (replace stored fp with 0, keep) ?
    1111       FGET-RET   Object Return from Frame Pointer
    

1011ccci  1    %BRANCH    Conditional Branch displace address with ww*256-256 | prefix, w optional Action: keep?
    000        BRANCH     Unconditional Jump

    001        NZJP       On Non Zero Jump    (keep)
    010        ZJP        On Zero Jump        (keep)
    011        ZJPDROP    On Zero Jump        (drop)

    100        CJP        On Carry Jump
    101        NCJP       On Not Carry Jump

    110        EJP        On Even Jump        (keep)
    111        OJP        On Odd Jump         (keep)
    

1011ccci  2    %IF       Branch past if first prefix #constant NOT MATCH TOS, second prefix use as in %BRANCH
    000        #=IF       Branch past if not #const =
    001        #<IF       Branch past if not #const <
    010        #BIF       Branch past if Bit #const is not set (0-15)
    011        #&IF       Branch past if mask & is 0

    100        #!=IF
    101        #>=IF         to compare > just modify constant!
    110        #B!IF
    111        #&!IF


8:

11000iii  0    FREAD#     Read memory from address (FP + iii) into TOS
110000rr  1    ZREAD      Read memory from 9-bit address (7-bit prefix,rr) into TOS
110000ii  2    READ       Read memory from full 16-bit address (14-bit template, ii) into TOS

8:

110010rr  0    REG#       Read internal register file index (rr) into TOS (No external RAM bus action)
110010rr  1    #READ#     Read memory from address (Register 0 + 7-bit prefix index) into TOS
110110rr  2    -

1100110r  0  0/1-RINC     Read memory from address in Reg (r), then automatically increment Reg value by 1
1100111r  0  2/3-RDEC     Automatically decrement Reg (r) value by 1, then read memory at that new address

11001100  1    TREAD      Read memory from address (TOS + 7-bit prefix index) into TOS (drop ?)
11001101  1    NREAD      Read memory from address (NOS + 7-bit prefix index) into TOS (overwrite TOS?)
11001110  1    RREAD      Read memory from address (ROS + 7-bit prefix index) into TOS (rdrop ?) 
11001111  1    FREAD      Read memory from address (FP  + 7-bit prefix index) into TOS
               SREAD      PICK alternative to one of the above...


8:

11010iii  0    FWRITE#    Write TOS data to memory address (FP + iii); pop stack
110100rr  1    ZWRITE     Write TOS data to 9-bit address (7-bit prefix, rr); pop stack
110100rr  2    WRITE      Write TOS data to full 16-bit address (14-bit 2 prefixes, rr); pop stack

8:

110110rr  0    WREG#      Write TOS data directly into internal register file index (rr); pop stack
110110rr  1    #WRITE#    Write TOS data to address (Register 0 + 7-bit prefix index); pop stack
110110rr  2    -

1101110r  0  0/1-WINC     Write TOS data to address in Reg (r), then automatically increment Reg value by 1
1101111r  0  2/3-WDEC     Automatically decrement Reg (r) value by 1, then write TOS data to that new address
11011100  1    TWRITE#    Write TOS data to address (TOS + 7-bit prefix index); pop stack
11011101  1    NWRITE#    Write TOS data to address (NOS + 7-bit prefix index); pop stack
11011110  1    RWRITE#    Write TOS data to address (ROS + 7-bit prefix index); pop stack
11011111  1    FWRITE#    Write TOS data to address (FP  + 7-bit prefix index); pop stack
110111r   2    -





????????  -    OPUSH      Object Push: push(fp); fp= TOS;
????????  -    OPOP       Object Pop:  fp= pop

????????  0    FPUSH      Frame Push: push(fp); fp= sp;
(see FRET, FJSR)

8: (maybe ok, if replaces OPUSH,OPOP, FPUSH, FPOP keeping FJSR, FRET "special")
??????rr  0    #POP       Pop TOS into Register rr
??????rr  0    #PUSH      Push Register rr onto stack


????????  0    IREAD      Indexed Read  (TOS+NOS)
????????  0    IWRITE     Indexed Write (TOS+NOS)

????????  -    INP        Input from port
????????  -    OUT        Output to port


10010xxx  0    -          stack ...
10011xxx  0    -          rstack...


== This is extended HASH/CRYPTO (save OPs: move to a "prefix" instr)
(32:)

8:

11100000  -    BREV       Full bit reversal of 16-bit TOS
11100001  -    BREVL      Reverse only lower 8 bits of TOS
11100010  -    BREVH      Reverse only upper 8 bits of TOS
11100011  -    BREV_NIB   Reverse bit-order inside every 4-bit nibble of TOS independently

11100100  -    SWAP8      Swap upper and lower 8-bit halves of TOS (Endian flip)
11100101  -    SWAP4      Swap adjacent 4-bit nibbles across full TOS
11100110  -    SWAP2      Swap adjacent 2-bit pairs across full TOS
11100111  -    ROT1       Rotate full TOS left by exactly 1 bit (TODO: ROR more important!!!)


8:

11101000  -    CHI0       Ascon/Keccak non-linear step: TOS <= TOS ^ (~NOS & (NOS << 1))
11101001  -    CHI1       Diffusion channel step: TOS <= TOS ^ (~NOS & (NOS << 2))
11101010  -    CHI2       Diffusion channel step: TOS <= TOS ^ (~NOS & (NOS << 3))
11101011  -    CHI3       Diffusion channel step: TOS <= TOS ^ (~NOS & (NOS << 5))

11101100  -    MAJ        Majority vote of TOS, NOS, NOS2; pop stack
11101101  -    MAJ_INV    Majority vote with inverted outcome bit stream; pop stack
11101110  -    MAJ_RSTK   Majority vote incorporating R_TOS register as third input vector; pop stack
11101111  -    MAJ_CARRY  Majority vote factoring in active hardware carry register bit; pop stack


8:

11110000  -    ADD        Standard arithmetic addition: TOS <= TOS + NOS; pop NOS
11110001  -    ADC        Add with carry: TOS <= TOS + NOS + carry; update carry register; pop NOS
11110010  -    ADN        Add without affecting flags: TOS <= TOS + NOS; ignore carry updates; pop NOS
11110011  -    ADS        Add with sign adjustments: TOS <= TOS + NOS + carry; toggle sign on overflow; pop NOS

11110100  -    SUB        Standard arithmetic subtraction: TOS <= NOS - TOS; pop NOS
11110101  -    SBC        Subtract with borrow: TOS <= NOS - TOS - carry; update carry register; pop NOS
11110110  -    SBN        Subtract without affecting flags: TOS <= NOS - TOS; ignore carry updates; pop NOS
11110111  -    SBS        Reverse arithmetic subtraction: TOS <= TOS - NOS; pop NOS


8:

11111000  -    CLMUL      Galois Field carryless multiplication step: TOS <= (NOS & 1) ? (TOS ^ NOS) : TOS
11111001  -    CLMUL_ACC  Carryless multiplication with immediate accumulation into active hardware carry bit
11111010  -    CLMUL_REV  Carryless multiplication parsing bits from MSB direction down to LSB track
11111011  -    CLMUL_INV  Carryless multiplication outputting completely inverted result stream arrays

11111100  -    MULDIF0    Feistel avalanche: Multiply lower 8 bits of TOS/NOS, XOR result with full TOS
11111101  -    MULDIF1    Feistel avalanche: Multiply lower 8 bits of TOS/NOS, ADD result to full TOS via carry chain

11111110  -    WEYL       Cryptographic Weyl-addition mix step: TOS <= (ROL_AMT(NOS) ^ TOS) + 16'h9E37; pop NOS

11111111  -    TRUE       Push -1; if prefix_count > 0, shift TOS left 7 and XOR invert full register contents


