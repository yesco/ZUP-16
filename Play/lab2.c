#include <stdio.h>

int cnt = 0;

// Wraps the assignment into a structured block to force a top-to-bottom sequence point
#define LABEL(name) struct { int dummy; } name##_lbl = { (name = __COUNTER__ - cnt) * 0 },

// Every byte emitted increments our tracking variable by 1
#define EMIT(b)     struct { int dummy; } : { (__COUNTER__ * 0 + cnt++, b) },

int main() {
  int bar, fie, fum, end;

  // This structure behaves exactly like your byte array, but tracks labels cleanly
  struct {
    LABEL(bar)
    EMIT(42)
    EMIT(4)
    EMIT(5)

    LABEL(fie)
    EMIT(17)
    EMIT(17)

    LABEL(fum)
    EMIT(0)

    LABEL(end)
    struct { int dummy; } : {0}; // Terminator
  } program;

  // We cast the structure to a char pointer to read it exactly like a raw byte array
  char *foo = (char *)&program;

  // Outputs: 0 3 5 6 with ZERO warnings or errors on Clang!
  printf("Label positions: %d %d %d %d\n", bar, fie, fum, end);
  printf("Byte array contents: %d %d %d\n", foo[0], foo[1], foo[2]);
  
  return 0;
}
