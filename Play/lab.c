#include <stdio.h>

int cnt= 0;
#define LABEL(name) (name=__COUNTER__ - cnt++)*0+
#define EMIT(b) (__COUNTER__*0+(b)),

int main() {
  int bar, fie, fum, end;

  char foo[]= {
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
    0
  };

  printf("%d %d %d %d\n", bar, fie, fum, end);
  return 0;
}
  
