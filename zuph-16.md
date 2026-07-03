Bits      Pre  Mnemonic   Description
0iiiiiii  -    LIT#       Accumulate 7-bit literal; if prefix_count=0 push new, else shift TOS left 7 and XOR inject
11111111  -    P_NEG1     Push -1; if prefix_count > 0, shift TOS left 7 and XOR invert full register contents

1000iiii  -    TOGGLE#    Toggle bit (15 - iiii) of TOS; old bit moves to carry register
1001iiii  -    CSET#      Set bit (15 - iiii) of TOS equal to current carry register value
1010iiii  -    BINS#      Insert bit 0 of NOS into bit (15 - iiii) of TOS; pop NOS

1011xxxx  -    -          Unused slot (16 opcodes available for Flow Control / Branching)

11000iii  0    FPREAD#    Read memory from address (FP + iii) into TOS
110000rr  1    ZPREAD     Read memory from 9-bit address (7-bit prefix + rr) into TOS
110000rr  2    READ       Read memory from full 16-bit address (14-bit template + rr) into TOS

110010rr  0    RREAD      Read internal register file index (rr) into TOS (No external RAM bus action)
11001000  1    R0READ     Read memory from address (Register 0 + 6-bit prefix index) into TOS
11001001  1    R1READ     Read memory from address (Register 1 + 6-bit prefix index) into TOS
11001010  1    R2READ     Read memory from address (Register 2 + 6-bit prefix index) into TOS
11001011  1    R3READ     Read memory from address (Register 3 + 6-bit prefix index) into TOS
11001100  1    TREAD      Read memory from address (TOS + 6-bit prefix index) into TOS
11001101  1    NREAD      Read memory from address (NOS + 6-bit prefix index) into TOS
11001110  1    RSTKREAD   Read memory from address (R_TOS + 6-bit prefix index) into TOS
11001111  1    FPREAD     Read memory from address (FP + 6-bit prefix index) into TOS
1100110r  0    RREADINC   Read memory from address in Reg (r), then automatically increment Reg value by 1
1100111r  0    RREADDEC   Automatically decrement Reg (r) value by 1, then read memory at that new address

11010iii  0    FPWRITE#   Write TOS data to memory address (FP + iii); pop stack
110100rr  1    ZPWRITE    Write TOS data to 9-bit address (7-bit prefix + rr); pop stack
110100rr  2    WRITE      Write TOS data to full 16-bit address (14-bit template + rr); pop stack

110110rr  0    RWRITE     Write TOS data directly into internal register file index (rr); pop stack
11011000  1    R0WRITE    Write TOS data to address (Register 0 + 6-bit prefix index); pop stack
11011001  1    R1WRITE    Write TOS data to address (Register 1 + 6-bit prefix index); pop stack
11011010  1    R2WRITE    Write TOS data to address (Register 2 + 6-bit prefix index); pop stack
11011011  1    R3WRITE    Write TOS data to address (Register 3 + 6-bit prefix index); pop stack
11011100  1    TWRITE     Write TOS data to address (TOS + 6-bit prefix index); pop stack
11011101  1    NWRITE     Write TOS data to address (NOS + 6-bit prefix index); pop stack
11011110  1    RSTKWRITE  Write TOS data to address (R_TOS + 6-bit prefix index); pop stack
11011111  1    FPWRITE    Write TOS data to address (FP + 6-bit prefix index); pop stack
1101110r  0    RWRITEINC  Write TOS data to address in Reg (r), then automatically increment Reg value by 1
1101111r  0    RWRITEDEC  Automatically decrement Reg (r) value by 1, then write TOS data to that new address

11100000  -    BREV       Full bit reversal of 16-bit TOS
11100001  -    BREVL      Reverse only lower 8 bits of TOS
11100010  -    BREVH      Reverse only upper 8 bits of TOS
11100011  -    BREV_NIB   Reverse bit-order inside every 4-bit nibble of TOS independently
11100100  -    SWAP8      Swap upper and lower 8-bit halves of TOS (Endian flip)
11100101  -    SWAP4      Swap adjacent 4-bit nibbles across full TOS
11100110  -    SWAP2      Swap adjacent 2-bit pairs across full TOS
11100111  -    ROT1       Rotate full TOS left by exactly 1 bit

11101000  -    CHI0       Ascon/Keccak non-linear step: TOS <= TOS ^ (~NOS & (NOS << 1))
11101001  -    CHI1       Diffusion channel step: TOS <= TOS ^ (~NOS & (NOS << 2))
11101010  -    CHI2       Diffusion channel step: TOS <= TOS ^ (~NOS & (NOS << 3))
11101011  -    CHI3       Diffusion channel step: TOS <= TOS ^ (~NOS & (NOS << 5))
11101100  -    MAJ        Majority vote of TOS, NOS, NOS2; pop stack
11101101  -    MAJ_INV    Majority vote with inverted outcome bit stream; pop stack
11101110  -    MAJ_RSTK   Majority vote incorporating R_TOS register as third input vector; pop stack
11101111  -    MAJ_CARRY  Majority vote factoring in active hardware carry register bit; pop stack

11110000  -    ADD        Standard arithmetic addition: TOS <= TOS + NOS; pop NOS
11110001  -    ADC        Add with carry: TOS <= TOS + NOS + carry; update carry register; pop NOS
11110010  -    ADN        Add without affecting flags: TOS <= TOS + NOS; ignore carry updates; pop NOS
11110011  -    ADS        Add with sign adjustments: TOS <= TOS + NOS + carry; toggle sign on overflow; pop NOS

11110100  -    SUB        Standard arithmetic subtraction: TOS <= NOS - TOS; pop NOS
11110101  -    SBC        Subtract with borrow: TOS <= NOS - TOS - carry; update carry register; pop NOS
11110110  -    SBN        Subtract without affecting flags: TOS <= NOS - TOS; ignore carry updates; pop NOS
11110111  -    SBS        Reverse arithmetic subtraction: TOS <= TOS - NOS; pop NOS

11111000  -    CLMUL      Galois Field carryless multiplication step: TOS <= (NOS & 1) ? (TOS ^ NOS) : TOS
11111001  -    CLMUL_ACC  Carryless multiplication with immediate accumulation into active hardware carry bit
11111010  -    CLMUL_REV  Carryless multiplication parsing bits from MSB direction down to LSB track
11111011  -    CLMUL_INV  Carryless multiplication outputting completely inverted result stream arrays
11111100  -    MULDIF0    Feistel avalanche: Multiply lower 8 bits of TOS/NOS, XOR result with full TOS
11111101  -    MULDIF1    Feistel avalanche: Multiply lower 8 bits of TOS/NOS, ADD result to full TOS via carry chain
11111110  -    WEYL       Cryptographic Weyl-addition mix step: TOS <= (ROL_AMT(NOS) ^ TOS) + 16'h9E37; pop NOS


