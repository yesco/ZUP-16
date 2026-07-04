#include <stdio.h>

// 1. Establish a global baseline for the counter
#define AS_START()          enum { __as_base = __COUNTER__ + 1 }

// 2. Define a macro label that creates a global compile-time constant
#define AS_LABEL(name)      name = (__COUNTER__ - __as_base)

// 3. Every byte emitted must still advance the counter
#define EMIT_BYTE(b)        (__COUNTER__ * 0 + (b))

// 4. Your variable-byte literal macros
#define LIT1(n)             EMIT_BYTE(n)
#define LIT2(n)             EMIT_BYTE((n) & 0x3F), EMIT_BYTE((n) >> 6)


// Initialize the global baseline
AS_START();

//int lbl_init, lbl_mid, lbl_target;

// The Global Symbol Table
// This must mimic the exact layout of the array below
enum GlobalLabels {
    AS_LABEL(lbl_init),     // Captures index 0
    LIT1(1),                // Moves counter forward 1 slot
    
    AS_LABEL(lbl_mid),      // Captures index 1
    LIT2(1),                // Moves counter forward 2 slots
    
    AS_LABEL(lbl_target),   // Captures index 3
    LIT1(3)                 // Moves counter forward 1 slot
};

// The actual Global Read-Only Bytecode Array
// It will be perfectly synchronized with the enum above
const unsigned char bytecode[] = {
    LIT1(42),    // Matches lbl_init (Index 0)
    LIT2(95),    // Matches lbl_mid  (Index 1, occupies 1 and 2)
    LIT1(10)     // Matches lbl_target (Index 3)
};

int main() {
    // These are now global compile-time constants!
    printf("Global Label 'lbl_init'   is at index: %d\n", lbl_init);   // Outputs 0
    printf("Global Label 'lbl_mid'    is at index: %d\n", lbl_mid);    // Outputs 1
    printf("Global Label 'lbl_target' is at index: %d\n", lbl_target); // Outputs 3

    // Proof that the global data maps perfectly
    printf("Value at lbl_target: %d\n", bytecode[lbl_target]);       // Outputs 10
    return 0;
}
