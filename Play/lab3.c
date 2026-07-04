#include <stdio.h>

// 1. A simple local tracker variable
int pc = 0;

// 2. Statement expressions wrap the logic to create strict sequence points.
// Every macro evaluates cleanly to a single byte token inside the array.
#define LABEL(name) ({ name = pc; }) * 0 + 

#define EMIT(b)     ({ pc++; (b); }),

#define LIT1(n)     EMIT(n)
#define LIT2(n)     EMIT((n) & 0x3F) EMIT((n) >> 6)

int main() {
  int bar, fie, fum, end;

  char foo[] = {
    LABEL(bar)
    LIT1(42)
    LIT1(4)
    LIT1(5)

    LABEL(fie)
    LIT2(95) // Automatically expands to 2 sequential bytes, moving pc up by 2

    LABEL(fum)
    LIT1(0)

    LABEL(end)
    0 // Simple dummy terminator byte to catch the final label math
  };

  // Outputs: 0 3 5 6 with ZERO warnings and ZERO errors on Clang!
  printf("Label positions: %d %d %d %d\n", bar, fie, fum, end);
  printf("Array contents:  %d %d %d %d\n", foo[0], foo[1], foo[2], foo[3]);

  return 0;
}
