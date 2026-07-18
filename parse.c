// Parse.c - simple 8byte tokenizer

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>

typedef uint64_t token;

char* readfile(char* filename) {
    FILE *f = fopen(filename, "rb");
    if (!f) return NULL;

    if (fseek(f, 0, SEEK_END) != 0) return NULL;
    long len = ftell(f);
    if (len == -1) return NULL;
    rewind(f);

    char *b = calloc(1, len + 1);
    if (!b) goto fail;

    long n = fread(b, 1, len, f);
    if (n < len) { free(b); b = NULL; }

 fail:
    if (f) fclose(f);

    return b;
}


int main() {
  token a, b;
  
  char *f= readfile("parse.c"), *s= f;

  while(*s) putchar(*s++);

  free(f);
}
