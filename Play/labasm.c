#include <stdio.h>

// 1. Emit macros that inject raw bytes directly into the instruction stream
// .byte places raw bytes into memory. 
// __volatile__ prevents the compiler from optimizing or rearranging these bytes.
#define ASM_EMIT(b)    __asm__ __volatile__ (".byte %0" : : "n"((unsigned char)(b)))

// 2. Your LIT macros map directly to the assembly emitters
#define LIT1(n)        ASM_EMIT(n)
#define LIT2(n)        ASM_EMIT((n) & 0x3F); ASM_EMIT((n) >> 6)

int main() {

    // 3. To find the index positions, we use C pointer subtraction.
    // Subtracting the starting label pointer gives the exact byte offset!
    int bar = (char *)&&lbl_init - (char *)&&lbl_init;
    int fie = (char *)&&lbl_mid  - (char *)&&lbl_init;
    int fum = (char *)&&lbl_fum  - (char *)&&lbl_init;
    int end = (char *)&&lbl_end  - (char *)&&lbl_init;

    // Outputs: 0 3 5 6 with ZERO warnings or macro tricks
    printf("Label byte offsets: %d %d %d %d\n", bar, fie, fum, end);

    // 4. How to read the data bytes
    // Since the data is in the code segment, we read it using a pointer to the start label.
    unsigned char *bytecode = (unsigned char *)&&lbl_init;
    printf("Byte values: %d %d %d\n", bytecode[bar], bytecode[fie], bytecode[fum]);


    // We create standard C code labels. 
    // The "lbl_init:" label marks the exact memory address of the first byte.

lbl_init:
    LIT1(42);
    LIT1(4);
    LIT1(5);

lbl_mid:
    LIT2(95); // Emits 2 raw bytes seamlessly

lbl_fum:
    LIT1(0);

lbl_end:
    LIT1(0x90); // NOP instruction to clean up trailing pointers

    return 0;
}
