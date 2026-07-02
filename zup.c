#include <stdio.h>
#include <stdint.h>
#include <assert.h>

typedef uint16_t word;

word tos, nos, nos2, stack[64];
word* sp= stack;

word R, R2, fp, rstack[32];
word* rp= rstack;

word pc;

char prefix= 0;
char op, four;

uint32_t tmp, C;

word memw[32*1024]; // hibyte: odd byteaddr

char bread(word a) {
  word w= memw[a/2];
  if (a & 1) return w>>8; 
  return w;
}

void bwrite(word a, char b) {
  word w= memw[a/2];
  if (a & 1) w= (w & 0xff)   | (b << 8);
  else       w= (w & 0xff00) | b;
  memw[a/2]= w;
}

// if sign bit set: operate on byte
word memread(word tos, char four, word index) {
  word addr= ((tos << 4) | four) + index;
  if (((int16_t)tos) < 0) return bread(addr);
  else         return memw[addr];
}

// if sign bit set: operate on byte
void memwrite(int16_t tos, char four, word index, word val) {
  word addr= ((tos << 4) | four) + index;
  if (((int16_t)tos) < 0) bwrite(addr, val);
  else         memw[addr]= val;
}

void push(word w) {
  *sp++ = nos2;
  nos2= nos; nos= tos; tos= w;
}
	  
word pop() {
  word w= tos;
  tos= nos; nos= nos2;
  nos2= *--rp;
  return w;
}

void rpush(word w) {
  *rp++= R2;
  R2= R; R= w;
}

word rpop() {
  word w= R;
  R= R2; R2= *--rp;
  return w;
}

void jsr(word w) {
  rpush(pc);
  pc= w;
}

void ret() {
  pc= rpop();
}


// assembler!

word wc= 0;
char isprefix= 0;

void emit(char b) {
  bwrite(pc+wc, b);
  ++wc;

  isprefix= 0;
}

void _NOP();

int rlit(word a) {
  int r= 0;
  if (a >= 64) r= rlit(a>>6);
  emit(a & 0b111111);
  return r+1;
}

void LIT(word a) {
  // protect
  if (isprefix) _NOP();
  // serve
  // TODO: negative -1 opt
  isprefix= rlit(a);
}

// assumes have 16 bit addressing varaible
// and capturing all prefix 0,1,2
void emit16(word a, char op) {
  if (a >= 16) LIT(a >> 4); else if (isprefix) _NOP();
  emit(op + (a & 0xf));
}

void READ(word a)  { emit16(a, 0x40); }
void WRITE(word a) { emit16(a, 0x50); }


void JSR(word a)   { emit16(a, 0x60); }
void EXEC()        { JSR(0); }
void BEGIN()       { JSR(1); }


void RET(word c)   { emit(0x70+c); assert(c<32); }

void ZRET() { RET( 0); }
void CRET() { RET( 4); }
void NRET() { RET( 8); }
void ORET() { RET(12); }

void NZRET() { RET(16); }
void NCRET() { RET(20); }
void PRET()  { RET(24); }
void ERET()  { RET(28); }


void JP(word cond, word lab) {
  // TODO:
  emit(lab-wc);
  emit(0x80+cond);
}

void ZJP(word lab)     { JP( 0, lab); }
void CJP(word lab)     { JP( 4, lab); }
void NJP(word lab)     { JP( 8, lab); }
void OJP(word lab)     { JP(12, lab); }

void NZJP(word lab)    { JP(16, lab); }
void NCJP(word lab)    { JP(20, lab); }
void PJP(word lab)     { JP(24, lab); }
void EJP(word lab)     { JP(28, lab); }


// TODO: prefixes? limit, 15 special
void FREAD(word i) { emit16(0xA0, i); }
void FWRITE(word i){ emit16(0xB0, i); }

void FDEC(word i)  { emit(0xC0+i); assert(i<16); }
void FINC(word i)  { emit(0xC8+i); assert(i<16); }

void FSHR(word i)  { emit(0xD0+i); assert(i<16); }
void FSHL(word i)  { emit(0xD8+i); assert(i<16); }



void _INC()         { emit(0xE0); }
void _DEC()         { emit(0xE1); }

void _ROR()         { emit(0xE2); }
void _ASR()         { emit(0xE3); }
void _SHR()         { emit(0xE4); }
void _SHR4()        { emit(0xE5); }
void _SHL()         { emit(0xE6); }
void _SHL4()        { emit(0xE7); }


void _MUL()         { emit(0xE9); }
void _NOP()         { emit(0xEA); }

void _ROT()         { emit(0xEB); }
void _SWAP()        { emit(0xEC); }
void _OVER()        { emit(0xED); }
void _TUCK()        { emit(0xEE); }
void _DUP()         { emit(0xFF); }


void _ADD()         { emit(0xF0); }
void _ADC()         { emit(0xF1); }
void _SUB()         { emit(0xF2); }
void _FMA()         { emit(0xF3); }

void _AND()         { emit(0xF4); }
void _OR()          { emit(0xF5); }
void _XOR()         { emit(0xF6); }
void _DROP()        { emit(0xF7); }


void _RPOP()        { emit(0xF8); }
void _RPUSH()       { emit(0xF9); }
void _RPEEK()       { emit(0xFA); }

void _FPEEK()       { emit(0xFB); }
void _SET()         { emit(0xFC); }

void _BSWAP()       { emit(0xFD); }
void _SIGN()        { char n= isprefix; emit(0xFE); isprefix= n; }
void _TRUE()        { emit(0xFF); isprefix= 1; }



void _STR(char* s) {
  while(*s) emit(*s++);
  emit(0);
}

// capture 0 or 1 number! more: delimit with NOP

#define PRE         }; if (sizeof(arr)) LIT(arr[0]); }
#define POST        { word arr[]= {


#define INC         PRE _INC(); POST
#define DEC         PRE _DEC(); POST

#define ROR         PRE _ROR(); POST
#define ASR         PRE _ASR(); POST
#define SHR         PRE _SHR(); POST
#define SHR4        PRE _SHR4(); POST
#define SHL         PRE _SHL(); POST
#define SHL4        PRE _SHL4(); POST


#define MUL         PRE _MUL(); POST
#define NOP         PRE _NOP(); POST

#define ROT         PRE _ROT(); POST
#define SWAP        PRE _SWAP(); POST
#define OVER        PRE _OVER(); POST
#define TUCK        PRE _TUCK(); POST
#define DUP         PRE _DUP(); POST


#define ADD         PRE _ADD(); POST
#define ADC         PRE _ADC(); POST
#define SUB         PRE _SUB(); POST
#define FMA         PRE _FMA(); POST

#define AND         PRE _AND(); POST
#define OR          PRE _OR(); POST
#define XOR         PRE _XOR(); POST
#define DROP        PRE _DROP(); POST


#define RPOP        PRE _RPOP(); POST
#define RPUSH       PRE _RPUSH(); POST
#define RPEEK       PRE _RPEEK(); POST

#define FPEEK       PRE _FPEEK(); POST
#define FSET        PRE _FSET(); POST

#define BSWAP       PRE _BSWAP(); POST
#define SIGN        PRE _SIGN(); POST
#define TRUE        PRE _TRUE(); POST

#define PUTH        PRE JSR(0xB); POST
#define PUTN        PRE JSR(0xC); POST
#define PUTS        PRE JSR(0xD); POST
#define GETCHAR     PRE JSR(0xE); POST
#define PUTCHAR     PRE JSR(0xF); POST

#define STR(s)      PRE _STR(s); POST

#define LABEL(name) int name= wc+pc;

void setup() {
  pc= 1024; wc= 0;

  POST
    0x1234 NOP 0x5678 PUTH PUTN
    PUTS STR("foobar")
    NOP NOP 1 NOP 0 NOP 2 NOP 0 NOP 3 NOP 0
    NOP 42 NOP 17 NOP 42 SWAP 0 DROP 33
    NOP 4711
    TRUE
    77
    ADD
    PRE
    
  // TODO resolve labels and jumps...
};
  
int main() {
  
  printf("ZUP-16 Emulator\n\n");

  setup();
  
 next:
  op= bread(pc);
  
  C= !!C; // normalize Carry => 0 or 1
  four= op & 0xF; // get lowest four bits
  
  printf("%04x: %02x  %04x %04x %04x  R:%04x %04x  Fr:%04x\n",
	 pc, op,  tos, nos, nos2,  R, R2,  fp);


  switch (op) {

    // 64 PREFIX BUILD CONSTANTS (PFIX) = sh6lxor#
  case 0x00 ... 0x3F: {
    if (!prefix) push(0);
    //tos= (tos<<6) | ( (op&63) ^ (tos>>12) );
    tos= (tos<<6) | (op&63);
    ++prefix;
    goto isprefix; }


    // == 16+16 READ/WRITES (write / barts)
    //   * SIGN BIT: WORD / BYTE ADDRESSING using indexed slots 
    //       0 : WORD INDEX 15-bit hardware words. 64KB 
    //       1 : BYTE INDEX 15-bit bytes.          32KB 
    //     NOTE: bytes can only address half the memory (lower); baddr=waddr*2 

  case 0x40 ... 0x4F: {
    // READ

    // CASE prefix_count OF
    switch (prefix) {

      //     0 (1 Byte)  : REGISTER. Addresses global slots 0 ... 15 directly. 
      //                   Address = { 11'b000000000000, ir[3:0] } 
    case 0: push(memw[four]); break;

      //     1 (2 Bytes) : 10 bits address read/write. Range 0-1023. 
      //                   Address = { 0….0,   tos[5:0], ir[3:0] }
      //     2 (3 Bytes) : Absolute Far Write. Full 16-bit address. 
      //                   Address = {   tos[11:0],      ir[3:0] }
    case 1:
    case 2: tmp= pop(); push(memread(tmp, four, 0)); break;

    }
      
    break; }

  case 0x50 ... 0x5F: {
    // WRITE

    // CASE prefix_count OF
    switch (prefix) {

      //     0 (1 Byte)  : REGISTER. Addresses global slots 0 ... 15 directly. 
      //                   Address = { 11'b000000000000, ir[3:0] } 
    case 0: memw[four]= pop(); break;

      //     1 (2 Bytes) : 10 bits address read/write. Range 0-1023. 
      //                   Address = { 0….0,   tos[5:0], ir[3:0] }
      //     2 (3 Bytes) : Absolute Far Write. Full 16-bit address. 
      //                   Address = {   tos[11:0],      ir[3:0] }
    case 1:
    case 2: tmp= pop(); memwrite(tmp, four, 0, tos); break;

    }
      
    break; }
   

    // 16 SUBROUTINES (jsr)
  case 0x60 ... 0x6F:
    // 0x60 ... 0x6F    : CASE prefix_count OF 
    switch (prefix) {

      //     0 (1 Byte)  : Fast Vector JSR# (0-15) to Top of Memory, 8 byte slots, 
      //                   Address = { 9'b111111111, ir[3:0], 3'b000 } 
      //        SPECIAL VECTORS  
    case 0:
      switch (op) {

	//          0 : JSRTOS  - Jump SubRoutine to TOS. Method dispatch. 
      case 0x60: jsr(pop()); break;

	//          1 : BEGIN   - Begin loop; inject PC+1 into R2, push old R2. 
      case 0x61: push(R); R2= pc+1; break;


	// TODO: remove, use IO?
	
	//         12 : PUTH - print hex
      case 0x6B: printf("%x ", pop());
	++pc; goto next;

	//         12 : PUTN - print number
      case 0x6C: printf("%d ", pop());
	++pc;; goto next;

	//         13 : PUTS - print string after caller, return after
      case 0x6D: {
	tmp= pc;
	while((four= bread(++tmp))) putchar(four);
	pc= tmp+1; goto next; } // TODO: break; fails? why?

	//         14 : GETCHAR
      case 0x6E: push(getchar()); break;

	//         15 : PUTCHAR
      case 0x6F: putchar(pop()); break;

	//          i : USER#   - 2-15: USER DEFINED single byte code instructions! 
      defaalt: jsr(0b1111111110000000 + 8*four); break;

      }

      //     1 (2 Bytes) : Absolute Near JSR (Replaces lower 10 bits of PC). 
      //                   Address = { PC[15:10], tos[5:0], ir[3:0] } 
    case 1: jsr((tos<<4) | four); break; // TODO: fix relative window?

      //     2 (3 Bytes) : Absolute Far JSR (Full 16-bit address overwrite). 
      //                   Address = {        tos[11:0]   , ir[3:0] } 
    case 2: jsr((tos<<4) | four); break; // TODO: fix

    }

    // 16 SPECIALISED STREAMING CONTROL FUNCTIONS
  case 0x70 ... 0x7F: {
    break; }
    //   These are highly specialized single byte loop control. 
    //   They require the return stack to contain loopback address in R2, 
    //   Control counter/search valuemin R. Set by BEGIN. 
    // CASE prefix_count OF 
    //      0 : LOOPING CONDITIONALS using return! - see section below 
    //      1 :         : 6-10 bits imm data w 0-63 prefix! FUTURE INSTR?       
    //      2 : OF      : #=ifNjmp#n compare one prefix constant w nos, NE jmp 

    // = 1 prefix 
    //   0xxx           : 8 instructions FREE w 6-bit constant / 9 bits 
    //   1000   STEP#   : R-= prefix! 
    //   1xxx           : 7 FREE w 6-bit constant / 8.825 bits, lol 

    // = No prefix 
    //   0000   RET     : Unconditional return. 
    //   0001   PUMP    : Pulls a single cell from (NOS) into TOS; advances NOS. 
    //   0010   FLUSHn  : Writes a single cell from TOS out to (N2); advances N2. 
    //   0011   ?SHR    : Conditional Shift Right. Clears bits / shifts TOS, increments tracking count in R. Popcoubt if P2==PC 

    //   = LOOP BACK if TOS != R, otherwise continue. 
    //   0100   =WAIT ? : Spinlock. Wait for TOS == R. For hardware IO flags? 
    //   0101   =IN     : Streams from (NOS++) into TOS, until TOS == R. 
    //   0110   =OUT  ? : Blasts TOS to (N2++), until a hardware flag matches R. 
    //   0111   =STREAM : Pipelined copies (NOS> to (N2) until TOS == R. 

    //   —- COUNTING OPERATORS (all counts R–) 
    //   1000   STEP  ? :  Variable stride modifier. (R <= R - TOS). 
    //   1001   IN      : Pulls a cell from (NOS++) to TOS, dec counter R. 
    //   1010   OUT     : Writes TOS to N2, advances N2, dec counter R. 
    //   1011   ?LINK   : The true pointer-chaser. NOS= (NOS++). 

    //   = LOOP BACK if Dec R > 0, otherwise continue. 
    //   1100   NEXT    : Traditional FOR loop, loops to R2 if R > 0. 
    //   1101   ?IN     : Read in from (NOS++) to TOS, loops to R2. 
    //   1110   ?OUT    : FILL. If R2==PC. Continuous single-cycle filler. 
    //   1111   ?STREAM : Pipelined 1-cycle stream counted MOVE. If R2==PC. 


    // 32 CONDITIONAL RETURNS/BRANCHES 
  case 0x80 ... 0x9F: {

    if (prefix < 2) {
      // {100 n ccdd} 
      //   1 negation bit 
      //   2 Bits Condition [Z Minus Carry Odd] 
      //   2 Bits Displacement [-16  0 +16 +22] 
      //   Effective address = <R[15:6]+displacement> <tos 6 bits> 

      // % conditions: 
      // 0x80 ... 0x83    : z*        - Jump If     Zero (Z)           
      // 0x84 ... 0x87    : c*        - Jump If     Carry (C)   
      // 0x88 ... 0x8B    : m*        - Jump If     Minus (Sign bit)        
      // 0x8C ... 0x8F    : o*        - Jump If     Odd  (Lowest Bit)  

      // 0x90 ... 0x93    : nz*       - Jump If NOT Zero (NZ) 
      // 0x94 ... 0x97    : nc*       - Jump If NOT Carry (NC)   
      // 0x98 ... 0x9B    : p*        - Jump If NOT Minus (NS) = Positive (P) 
      // 0x9C ... 0x9F    : e*        - Jump If NOT Odd (Even)  

      char neg= op & 0b10000;
      char disp= 16 * ((op & 0b11)-1), yes;
      word addr= (pc & 0b1111111111000000) + disp + (tos & 0b111111);

      // jump?
      switch (op & 0b1100) {
      case 0b0000: yes= !tos; break;
      case 0b0100: yes= (tos<0); break;
      case 0b1000: yes= C; break;
      case 0b1100: yes= tos&1; break;
      }
      if (neg) yes= !yes;
      if (!yes) break;
      
      // 0 prefix      : %ret      - jump Be ACK from JSR on condition. 
      // 1 prefix      : %branch   - window absolute jump if true. 
      if (prefix) {

	// window jump
	pc= addr;

      } else {

	// return
	ret();

      }
      
    } else {

      // index read/write
      // addr= {  tos << 12, four } + nos
      tmp= pop();
      
      if (op <= 0x8f) {

	// 2 prefix 80-8F: iread     - indexed read (addr+tos) => val. 
	tos= memread(tmp, four, tos);
	     
      } else {

	//          90-9F: iwrite    - write nos to (addr+tos) => nos. 
	memwrite(tmp, four, tos, nos);

	// TODO: leaves index, val on stack (can't pop 2)
      }

  } break; }
  
    // 64 FRAME INDEXING OPERANDS (Fast-Path Block)
  case 0xA0 ... 0xDF: {
    break; }
    // 0xA0 ... 0xAE    : fread#      0 ... 14 : Reads slot (FR + index) to TOS. 
    // 0XAF             : fread                : -”-, index=TOS or prefix 1-2 bytes. 
    // 0xB0 ... 0xBE    : fwrite#     0 ... 14 : Copy & keep TOS to slot (FR + index). 
    // 0XAF             : fread                : -”-, index=TOS or prefix 1-2 bytes. 
    // 0xC0 ... 0xC7    : fread#dec   0 ...  7 : Reads slot. Push val-1 
    // 0xC8 ... 0xCF    : fread#inc   0 ...  7 : Reads slot. Push val+1 
    // 0xD0 ... 0xD7    : fshr#       0 ...  7 : Reads slot. Push shr, spills to C. 
    // 0xD8 ... 0xDF    : fshl#       0 ...  7 : Reads slot. Push shl, spills to C. 


    // == REGISTER MANIPULATION & STACK SHORTCUTS (Ode to 6502 Mapping)

  case 0xE0: ++tos; break; // inc      - Increment TOS by 1.
  case 0xE1: --tos; break; // dec      - Decrement TOS by 1.

    // ror      - Rotate C into TOS right by 1 bit. Spill to C. 
  case 0xE2: tmp= C; C= tos&1; tos= (tos>>1) + (tmp<<15); break;
    // asr      - Arithmetic shift TOS right 1 bit; spill to C. 
  case 0xE3: C= tos&1; *((int16_t*)&tos)>>= 1; break;
    // shr      - Shift TOS right by 1 bit; spill to Carry. 
  case 0xE4: C= tos&1; tos>>= 1; break;
    // shr4     - Shift TOS right by 4 bits (Nibble shift); C. 
  case 0xE5: C= tos&8; tos>>= 4; break;
    // shl      - Shift TOS left by 1 bit; spill to C. 
  case 0xE6: C= tos&(1<<15); tos<<= 1; break;
    // shl4     - Shift TOS left by 4 bits (Nibble shift); C. 
  case 0xE7: C= tos&(1<<12); tos<<= 4; break;

    //TODO: 0xE8          : rand  ?  - Randomization by gaussian. 

    // mul      - Multiply16x16=> TOS=High 16-bits, NOS=Low. 
  case 0xE9: tmp= tos*nos; tos= tmp>>16; nos= tmp&0xffff; break;
  case 0xEA: break; // nop      - No Operation; clears LIT_ACTIVE flag (6502).
    // rot      - Rotate three values. (-rot==rot rot)
  case 0xEB: tmp= tos; tos= nos; nos= nos2; nos2= tmp; break;

    // tuck     - Insert a copy of TOS underneath NOS. 
    // ">R DUP R> SWAP"
  case 0xEE: tmp= pop(); push(tos); push(tmp); 
    // fall through to SWAP!
    // swap     - Exchange the positions of TOS and NOS.
  case 0xEC: tmp= tos; tos= nos; nos= tmp; break;

  case 0xED: push(nos); break;  // over     - Copy NOS to the top of the stack.
  case 0xEF: push(tos); break;  // dup      - Duplicate TOS.


    // [0xF0 - 0xF7] : 8 MATH & LOGIC ALU CORE INSTRUCTIONS (a b -> c) 

    // add     - C; Push (NOS + TOS) to stack.
  case 0xF0: tmp= pop(); tos= tmp= tmp+tos; C= tmp>0xffff; break;
    // adc     - C; Push (NOS + TOS + C). (negate==-1 xor inc)
  case 0xF1: tmp= pop(); tos= tmp+tos+C; C= tmp>0xffff; break; 
    // sub     - C; Push (NOS - TOS). C=!borrow (sbc==adc sub)
  case 0xF2: tmp= pop(); tos= tmp-tos+C; C= tmp>0xffff; break; 

    // TODO: 0xF3          : fma  ?  - Fused Multiply-Add Step. 

  case 0xF4: tmp= pop(); tos&= tmp; break; // and     - Push (NOS bitwise AND TOS). 
  case 0xF5: tmp= pop(); tos|= tmp; break; // or      - Push (NOS bitwise OR TOS). 
  case 0xF6: tmp= pop(); tos^= tmp; break; // xor     - Push (NOS bitwise XOR TOS). (not==-1 xor) 
  case 0xF7: pop(); // drop    - Remove TOS. 

    // == [0xF8 - 0xFF] : 8 RETURN STACK, MOSTLY
  case 0xF8: push(*rp++); break;  // r>      - Move R to TOS. F same. 
  case 0xF9: rpush(pop()); break; // >r      - Move TOS to Return Stack. 
  case 0xFA: push(tos); break;    // rcopy   - Copy R to Data Stack (TOS). 

  case 0xFB: push(fp); fp= rpop(); break; // fcopy   - Drop R. Push frame on data stack. 
  case 0xFC: fp= pop(); break; //         // fset    - Frame register set. 

  case 0xFD: tos= (tos<<8) | (tos>>8); break;   //  bswap   - Swaps bytes.
  case 0xFE: tos= tos ^ (1<<15); goto isprefix; //  sign    - Flips sign bit.
  case 0xFF: push(-1); goto isprefix;           //  -1      - Minus one, aka True.
  }

  // most instructions reset prefix, unless they are modifier (sh6l# sign -1)
  prefix= 0;
  
 isprefix:
  ++pc;
  
  goto next;

  return 0;
}

