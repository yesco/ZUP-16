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

#ifdef OLD
// Safely extracts a character at index 'i' if it exists within the string literal length
#define CH(s, i) ((i) < (sizeof(s) - 1) ? (uint64_t)(s)[i] : 0)

// Standard C macro that shifts 7 bits progressively for up to 8 characters
#define T(s) ( \
    (sizeof(s) - 1 >= 1 ? CH(s, 0) : 0) \
    | (sizeof(s) - 1 >= 2 ? (CH(s, 0) << 7)  | CH(s, 1) : 0) \
    | (sizeof(s) - 1 >= 3 ? (CH(s, 0) << 14) | (CH(s, 1) << 7)  | CH(s, 2) : 0) \
    | (sizeof(s) - 1 >= 4 ? (CH(s, 0) << 21) | (CH(s, 1) << 14) | (CH(s, 2) << 7)  | CH(s, 3) : 0) \
    | (sizeof(s) - 1 >= 5 ? (CH(s, 0) << 28) | (CH(s, 1) << 21) | (CH(s, 2) << 14) | (CH(s, 3) << 7)  | CH(s, 4) : 0) \
    | (sizeof(s) - 1 >= 6 ? (CH(s, 0) << 35) | (CH(s, 1) << 28) | (CH(s, 2) << 21) | (CH(s, 3) << 14) | (CH(s, 4) << 7)  | CH(s, 5) : 0) \
    | (sizeof(s) - 1 >= 7 ? (CH(s, 0) << 42) | (CH(s, 1) << 35) | (CH(s, 2) << 28) | (CH(s, 3) << 21) | (CH(s, 4) << 14) | (CH(s, 5) << 7)  | CH(s, 6) : 0) \
    | (sizeof(s) - 1 >= 8 ? (CH(s, 0) << 49) | (CH(s, 1) << 42) | (CH(s, 2) << 35) | (s[3] ? (CH(s, 3) << 28) : 0) | (CH(s, 4) << 21) | (CH(s, 5) << 14) | (CH(s, 6) << 7) | CH(s, 7) : 0) \
)
#else

// Safely grabs char at index 'i' if within bounds, otherwise returns 0
#define CH(s, i) (((i) < (sizeof(s) - 1)) ? (uint64_t)(s)[i] : 0)

// Progressively nest the shifts from left to right (up to 8 characters)
#define T1(s) CH(s, 0)
#define T2(s) ((T1(s) << 7) | CH(s, 1))
#define T3(s) ((T2(s) << 7) | CH(s, 2))
#define T4(s) ((T3(s) << 7) | CH(s, 3))
#define T5(s) ((T4(s) << 7) | CH(s, 4))
#define T6(s) ((T5(s) << 7) | CH(s, 5))
#define T7(s) ((T6(s) << 7) | CH(s, 6))
#define T8(s) ((T7(s) << 7) | CH(s, 7))

// Route the string to the exact macro matching its length
#define T(s) ( \
    sizeof(s)==2 ? T1(s) : \
    sizeof(s)==3 ? T2(s) : \
    sizeof(s)==4 ? T3(s) : \
    sizeof(s)==5 ? T4(s) : \
    sizeof(s)==6 ? T5(s) : \
    sizeof(s)==7 ? T6(s) : \
    sizeof(s)==8 ? T7(s) : T8(s)  \
)

#endif

token pIf(char** s) 		{ return 0; }
token pWhile(char** s) 		{ return 0; }
token pDo(char** s) 		{ return 0; }
token pBreak(char** s) 		{ return 0; }
token pContinue(char** s) 	{ return 0; }
token pGoto(char** s) 		{ return 0; }
token pExpr(char** s, token t) 	{ return 0; }

token pStmt(char** s) {
  token t= next(s);
  switch(t) {
  case T("if"):       return pIf(s);
  case T("while"):    return pWhile(s);
  case T("do"):       return pDo(s);
  case T("break"):    return pBreak(s);
  case T("continue"): return pContinue(s);
  case T("goto"):     return pGoto(s);
  default:            return pExpr(s, t);
  }
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

