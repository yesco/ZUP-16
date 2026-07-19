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

// is tbase:
//   0: normal string token
//   8-16: base #
//   <0: illegal base #, token==illegal char
//   256>= -256 len bytes string
signed int tbase= 0; 

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

  tbase= 256+len; // lol
  // return as uint64!
  return (token)m;
}

token parseNum(char** s) {
  token t= 0;

  // base?
  if (STEP == '0' && isalnum(**s)) {
    switch(tolower(STEP)) {
    case 'x': case 'h': tbase= 16; break;
    case 'b': tbase= 2; break;
    case 'o': tbase= 8; break;
    default: t= lastchar-'0'; break;
    }
  } else { tbase= 10; t= lastchar-'0'; }

  // read number
  while (isalnum(**s) || **s == '_') {
    char d= toupper(STEP)-'0';
    if (lastchar == '_') continue;
    // TODO: handle decimals?
    if (d > 9) d-= 7;
    if (d >= tbase) { tbase= -tbase; return lastchar; }
    t*= tbase; t+= d;
    //printf("\n# %d %d %d '%c' \t\t\t", tbase, t, d, lastchar);
  }

  return t;
}


// Anything starting with a digit must be a number ala C
// Any token positive is complete
// A token with hibit set is truncated
token next(char** s) {
  token t= 0;
  
  tbase= 0;
  
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
  switch(tbase) {
  case  8: printf("#0o%lo ", t); return t;
  case 10: printf("#%ld ",   t); return t;
  case  2: 
  case 16: printf("#0x%lx ", t); return t;
  default: 
    if (tbase < 0) { printf("#%%'%c'@%d ", (char)t, tbase);        return t; }
    else           { printf("$%d:\"%s\" ", tbase-256, (char*)t);   return t; }
  case  0: break;
  }

  // truncated? (hibit set)
  if (((int64_t)t) < 0) putchar('%');

  token o= t;
  while(t) {
    char c= (t>>(64-8)) & 0x7f; // shift down oldest, remove top bit
    if (c) putchar(c);
    t<<= 7;
  }
  if (o != 10) putchar(' ');
  return t;
}

#include <stdio.h>
#include <stdint.h>

// Numeric Constant From String
// (Single char becomes it's ASCII)
#define TC(s, i) (((i) + 1 < sizeof(s)) ? (uint64_t)(s)[i] : 0)
#define TS(c, acc) ((c) == 0 ? (acc) : (((acc) << 7) | (c)))
#define TX(s, i, acc) TS(TC(s, i), acc)

#define T(s) TX(s,7,TX(s,6,TX(s,5,TX(s,4,TX(s,3,TX(s,2,TX(s,1,TC(s,0))))))))


char expect(char** s, token x) {
  if (next(s)==x) return 1;
  // fail
  printf("%%Expected: "); prtoken(x);
  printf(" Got: ");       prtoken(lasttok);
  exit(1);
}
	    
#define EXPECT(t) expect(s, T(t))
  


// TODO: probably make these functions take char* and return s as far as parsed!

token pExpr(char** s, token t) 	{ return 0; }

token parExpr(char** s) {
  EXPECT("(");;
  pExpr(s, next(s));
  EXPECT(")");
  return 1;
}
    
token pStmt(char** s); // forward

token pIf(char** s) {
  printf("===IF==\n");

  parExpr(s);
  pStmt(s);
  token t= next(s);
  if (t==T("else")) pStmt(s); else ; // TODO: undo, PEEK?
  return 1;
}

token pWhile(char** s) 		{ return 0; }
token pDo(char** s) 		{ return 0; }
token pBreak(char** s) 		{ return 0; }
token pContinue(char** s) 	{ return 0; }
token pGoto(char** s) 		{ return 0; }

token pStmt(char** s) {
  switch(next(s)) {
  case T("if"):       return pIf(s);
  case T("while"):    return pWhile(s);
  case T("do"):       return pDo(s);
  case T("break"):    return pBreak(s);
  case T("continue"): return pContinue(s);
  case T("goto"):     return pGoto(s);
  default:            return pExpr(s, lasttok);
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
    while((t= next(&s)) || tbase) prtoken(t);
    puts("----------------");
  }

  free(f);

  {
    //char* s= "if (0) 3; else 4;";
    char* s= "if (0) 3; 5;";
    token t;
    pStmt(&s);
    puts("----------------");
  }
  
}

// Test long symbols
// abcdefgh abcdefghi abcdefghij abcdefghijk
// 0 3 7 17 21 42 47 4711
// 0x12345678 0x7f
// Faulty numbers: 09 0xfk 47a3

