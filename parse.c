// Parse.c - simple 8byte tokenizer

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <ctype.h>
#include <unistd.h>

typedef uint64_t token;

char* readfile(char* filename) {
    FILE *f= fopen(filename, "rb");
    if (!f) return NULL;

    if (fseek(f, 0, SEEK_END) != 0) return NULL;
    long len= ftell(f);
    if (len == -1) return NULL;
    rewind(f);

    char *b= calloc(1, len + 1);
    if (!b) goto fail;

    long n= fread(b, 1, len, f);
    if (n < len) { free(b); b = NULL; }

 fail:
    if (f) fclose(f);

    return b;
}

#define STEP (*(*s)++)

void skipspc(char** s) {
  //  while(isspace(**s)) STEP;
  while(isblank(**s)) STEP;
}

#define TRUNC 0xff0000000000000

token next(char** s) {
  token t= 0;
  
  skipspc(s);

  // Gobble string (Not UTF-8 safe)
  while(isalnum(**s)) {
    if (t & TRUNC) t|= TRUNC;
    t<<= 7; t|= STEP;
  }
  
  // No string/num return char
  return t ? t : STEP;
}

token prtoken(token t) {
  char c;
  if (((int64_t)t) < 0) putchar('*');

  while(t) {
    c= (t>>(64-8)) & 0x7f; // shift down oldest, remove top bit
    if (c) putchar(c);
    t<<= 7;
  }
  putchar(' ');
  return t;
}

int main() {
  char *f= readfile("parse.c");

  {
    char* s= f;
    while(*s) putchar(*s++);
    puts("----------------");
  }

  {
    char* s= f;
    token t;
    while((t= next(&s))) prtoken(t);
    puts("----------------");
  }

  free(f);
}

// abcdefgh abcdefghi abcdefghij abcdefghijk

