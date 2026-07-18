// Parse.c - simple 8byte tokenizer

// --------------------------------------------------
// Settings

#define NL_TOKEN


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

char lastchar= 0;
#define STEP (lastchar=*(*s)++)

void skipspc(char** s) {
#ifdef NL_TOKEN
  while(isblank(**s)) STEP;
#else
  while(isspace(**s)) STEP;
#endif
}

#define TRUNC 0xff0000000000000

token lasttok= 0;

// is isbasenum:
//   0: normal string token
//   8-16: base #
//   <0: illegal base #, token==illegal char
//   256>= -256 len bytes string
signed int isbasenum= 0; 

token parseStr(char** s) {
  STEP;

  // Just count
  int len= 1;
  char* x= *s;
  while(*x && *x != '"') { if (*x == '\\') ++x; ++x; ++len; }
  
  
  char *m= calloc(1, len), *p= m;
  while(**s != '"') {
    // TODO: \r \n \0 \... \t \b \f
    if (**s == '\\') STEP;
    *p++= STEP;
  }
  STEP; // skip "

  isbasenum= 256+len; // lol
  // return as uint64!
  return (token)m;
}

token parseNum(char** s) {
  token t= 0;

  // base?
  if (STEP == '0' && isalnum(**s)) {
    switch(tolower(STEP)) {
    case 'x': case 'h': isbasenum= 16; break;
    case 'b': isbasenum= 2; break;
    case 'o': isbasenum= 8; break;
    default: t= lastchar-'0'; break;
    }
  } else { isbasenum= 10; t= lastchar-'0'; }

  // read number
  while (isalnum(**s) || **s == '_') {
    char d= toupper(STEP)-'0';
    if (lastchar == '_') continue;
    // TODO: handle decimals?
    if (d > 9) d-= 7;
    if (d >= isbasenum) { isbasenum= -isbasenum; return lastchar; }
    t*= isbasenum; t+= d;
    //printf("\n# %d %d %d '%c' \t\t\t", isbasenum, t, d, lastchar);
  }

  return t;
}


// Anything starting with a digit must be a number ala C
// Any token positive is complete
// A token with hibit set is truncated
token next(char** s) {
  token t= 0;
  
  isbasenum= 0;
  
  skipspc(s);

  if (isdigit(**s)) return parseNum(s);
  if (**s == '"')   return parseStr(s);
  
  // Gobble string (Not UTF-8 safe)
  while(isalnum(**s) || **s=='_') {
    if (t & TRUNC) t|= TRUNC | (t>>(64-8));
    t<<= 7; t^= STEP;
  }
  
  // No string/num return char
  return (lasttok= t ? t : STEP);
}

token prtoken(token t) {
  switch(isbasenum) {
  case  8: printf("#0o%lo ", t); return t;
  case 10: printf("#%ld ",   t); return t;
  case  2: 
  case 16: printf("#0x%lx ", t); return t;
  default: 
    if (isbasenum < 0) { printf("#%%'%c'@%d ", (char)t, isbasenum); return t; }
    else               { printf("$%d:\"%s\" ", isbasenum-256, (char*)t);   return t; }
  case  0: break;
  }

  // truncated? (hibit set)
  if (((int64_t)t) < 0) putchar('*');

  token o= t;
  while(t) {
    char c= (t>>(64-8)) & 0x7f; // shift down oldest, remove top bit
    if (c) putchar(c);
    t<<= 7;
  }
  if (o != 10) putchar(' ');
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
    while((t= next(&s)) || isbasenum) prtoken(t);
    puts("----------------");
  }

  free(f);
}

// Test long symbols
// abcdefgh abcdefghi abcdefghij abcdefghijk
// 0 3 7 17 21 42 47 4711
// 0x12345678 0x7f
// Faulty numbers: 09 0xfk 47a3

