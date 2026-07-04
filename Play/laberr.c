#include <stdio.h>

// 1. Label evaluates to a 0-byte multiplier, assigning the index to the variable
#define LABEL(name) (name = __COUNTER__ - baseline),

// 2. Emit just returns the raw byte value. It doesn't need to do any counter math!
#define EMIT(b)     (b),

int main() {
  int bar, fie, fum, end;

  // 3. Capture the exact starting value of the counter right before the array
  int baseline = __COUNTER__ + 1;

  char foo[]= {
    LABEL(bar)
    EMIT(42) // Index 0
    EMIT(4)  // Index 1
    EMIT(5)  // Index 2

    LABEL(fie)
    EMIT(17) // Index 3
    EMIT(17) // Index 4

    LABEL(fum)
    EMIT(0)  // Index 5

    LABEL(end)
    0        // Dummy element to terminate the last label assignment
  };

  // Outputs: 0 3 5 6
  printf("%d %d %d %d\n", bar, fie, fum, end);
  return 0;
}
