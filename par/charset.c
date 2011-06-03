/***********************/
/* charset.c           */
/* for Par 1.52-i18n.3 */
/* Copyright 2001 by   */
/* Adam M. Costello    */
/* Modified by         */
/* Jérôme Pouiller     */
/***********************/

/* This is ANSI C code (C89). */


/* Because this is ANSI C code, we can't assume that there are only 256 */
/* characters.  Therefore, we can't use bit vectors to represent sets   */
/* without the risk of consuming large amounts of memory.  Therefore,   */
/* this code is much more complicated than might be expected.           */


#include "charset.h"  /* Makes sure we're consistent with the.  */
                      /* prototypes.  Also includes "errmsg.h". */
#include "buffer.h"   /* Also includes <stddef.h>.              */

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include <wctype.h>

#undef NULL
#define NULL ((void *) 0)

#ifdef DONTFREE
#define free(ptr)
#endif


/* The issues regarding char and unsigned char are relevant to the  */
/* use of the ctype.h functions, and the interpretation of the _xhh */
/* sequence.  See the comments near the beginning of par.c.         */


typedef unsigned char csflag_t;

struct charset {
  wchar_t *inlist;    /* Characters in inlist are in the set.                */
  wchar_t *outlist;   /* Characters in outlist are not in the set.           */
                   /* inlist and outlist must have no common characters.  */
                   /* inlist and outlist may be NULL, which acts like "". */
  csflag_t flags;  /* Characters in neither list are in the set if they   */
                   /* belong to any of the classes indicated by flags.    */
};

/* The following may be bitwise-OR'd together */
/* to set the flags field of a charset:       */

static const csflag_t CS_UCASE = 1,  /* Includes all upper case letters. */
                      CS_LCASE = 2,  /* Includes all lower case letters. */
                      CS_DIGIT = 4,  /* Includes all decimal digits.     */
                      CS_NUL   = 8;  /* Includes the NUL character.      */


static int appearsin(wchar_t c, const wchar_t *str)

/* Returns 0 if c is '\0' or str is NULL or c     */
/* does not appear in *str.  Otherwise returns 1. */
{
  return c && str && wcschr(str,c);
}


static int hexdigtoint(wchar_t c)

/* Returns the value represented by the hexadecimal */
/* digit c, or -1 if c is not a hexadecimal digit.  */
{
  const wchar_t *p, * const hexdigits = L"0123456789ABCDEFabcdef";
  int n;

  if (!c) return -1;
  p = wcschr(hexdigits, c);
  if (!p) return -1;
  n = p - hexdigits;
  if (n >= 16) n -= 6;
  return n;

  /* We can't do things like c - 'A' because we can't */
  /* depend on the order of the characters in ANSI C. */
  /* Nor can we do things like hexdigtoint[c] because */
  /* we don't know how large such an array might be.  */
}


charset *parsecharset(const char *str, errmsg_t errmsg)
{
  charset *cset = NULL;
  buffer *cbuf = NULL;
  const wchar_t *p, * const singleescapes = L"_sbqQx";
  int hex1, hex2;
  wchar_t ch;
  wchar_t *wstr;
      
  wstr = (wchar_t *) malloc((strlen(str) + 1) * sizeof(wchar_t));
  if (!wstr) {
    wcscpy(errmsg,outofmem);
    goto pcserror;
  }
  if ((size_t)(-1) == mbstowcs(wstr, str, strlen(str) + 1)) {
    wcscpy(errmsg,mbserror);
    goto pcserror;
  }
  cset = malloc(sizeof (charset));
  if (!cset) {
    wcscpy(errmsg,outofmem);
    goto pcserror;
  }
  cset->inlist = cset->outlist = NULL;
  cset->flags = 0;

  cbuf = newbuffer(sizeof (wchar_t), errmsg);
  if (*errmsg) goto pcserror;

  for (p = wstr;  *p;  ++p)
    if (*p == L'_') {
      ++p;
      if (appearsin(*p, singleescapes)) {
        if      (*p == L'_') ch = L'_' ;
        else if (*p == L's') ch = L' ' ;
        else if (*p == L'b') ch = L'\\';
        else if (*p == L'q') ch = L'\'';
        else if (*p == L'Q') ch = L'\"';
        else /*  *p == 'x'  */ {
          /* FIXME _x metacharacter should allow wide characters input.*/
          hex1 = hexdigtoint(p[1]);
          hex2 = hexdigtoint(p[2]);
          if (hex1 < 0  ||  hex2 < 0) goto pcsbadstr;
          ch = 16 * hex1 + hex2;
          p += 2;
        }
        if (!ch)
          cset->flags |= CS_NUL;
        else {
          additem(cbuf, &ch, errmsg);
          if (*errmsg) goto pcserror;
        }
      }
      else {
        if      (*p == L'A') cset->flags |= CS_UCASE;
        else if (*p == L'a') cset->flags |= CS_LCASE;
        else if (*p == L'0') cset->flags |= CS_DIGIT;
        else goto pcsbadstr;
      }
    }
    else {
      additem(cbuf, p,errmsg);
      if (*errmsg) goto pcserror;
    }
  ch = '\0';
  additem(cbuf, &ch, errmsg);
  if (*errmsg) goto pcserror;
  cset->inlist = copyitems(cbuf,errmsg);
  if (*errmsg) goto pcserror;

pcscleanup:

  if (cbuf) freebuffer(cbuf);
  if (wstr) free(wstr);
  return cset;

pcsbadstr:

  swprintf(errmsg, errmsg_size, L"Bad charset syntax: %.*s\n", errmsg_size - 22, str);

pcserror:

  if (cset) freecharset(cset);
  cset = NULL;
  goto pcscleanup;
}


void freecharset(charset *cset)
{
  if (cset->inlist) free(cset->inlist);
  if (cset->outlist) free(cset->outlist);
  free(cset);
}


int csmember(wchar_t c, const charset *cset)
{
  return
    appearsin(c, cset->inlist) ||
    ( !appearsin(c, cset->outlist) &&
        ( (cset->flags & CS_LCASE && iswlower(*(wint_t *)&c)) ||
          (cset->flags & CS_UCASE && iswupper(*(wint_t *)&c)) ||
          (cset->flags & CS_DIGIT && iswdigit(*(wint_t *)&c)) ||
        (cset->flags & CS_NUL   && !c                           )   ) );
}


static charset *csud(
  int u, const charset *cset1, const charset *cset2, errmsg_t errmsg
)
/* Returns the union of cset1 and cset2 if u is 1, or the set    */
/* difference cset1 - cset2 if u is 0.  Returns NULL on failure. */
{
  charset *csu;
  buffer *inbuf = NULL, *outbuf = NULL;
  wchar_t *lists[4], **list, *p, nullchar = L'\0';

  csu = malloc(sizeof (charset));
  if (!csu) {
    wcscpy(errmsg,outofmem);
    goto csuderror;
  }
  inbuf = newbuffer(sizeof (wchar_t), errmsg);
  if (*errmsg) goto csuderror;
  outbuf = newbuffer(sizeof (wchar_t), errmsg);
  if (*errmsg) goto csuderror;
  csu->inlist = csu->outlist = NULL;
  csu->flags =  u  ?  cset1->flags |  cset2->flags
                   :  cset1->flags & ~cset2->flags;

  lists[0] = cset1->inlist;
  lists[1] = cset1->outlist;
  lists[2] = cset2->inlist;
  lists[3] = cset2->outlist;

  for (list = lists;  list < lists + 4;  ++list)
    if (*list) {
      for (p = *list;  *p;  ++p)
        if (u  ?  csmember(*p, cset1) ||  csmember(*p, cset2)
               :  csmember(*p, cset1) && !csmember(*p, cset2)) {
          if (!csmember(*p, csu)) {
            additem(inbuf,p,errmsg);
            if (*errmsg) goto csuderror;
          }
        }
        else
          if (csmember(*p, csu)) {
            additem(outbuf,p,errmsg);
            if (*errmsg) goto csuderror;
          }
    }

  additem(inbuf, &nullchar, errmsg);
  if (*errmsg) goto csuderror;
  additem(outbuf, &nullchar, errmsg);
  if (*errmsg) goto csuderror;
  csu->inlist = copyitems(inbuf,errmsg);
  if (*errmsg) goto csuderror;
  csu->outlist = copyitems(outbuf,errmsg);
  if (*errmsg) goto csuderror;

csudcleanup:

  if (inbuf) freebuffer(inbuf);
  if (outbuf) freebuffer(outbuf);
  return csu;

csuderror:

  if (csu) freecharset(csu);
  csu = NULL;
  goto csudcleanup;
}


charset *csunion(const charset *cset1, const charset *cset2, errmsg_t errmsg)
{
  return csud(1,cset1,cset2,errmsg);
}


charset *csdiff(const charset *cset1, const charset *cset2, errmsg_t errmsg)
{
  return csud(0,cset1,cset2,errmsg);
}


void csadd(charset *cset1, const charset *cset2, errmsg_t errmsg)
{
  charset *csu;

  csu = csunion(cset1,cset2,errmsg);
  if (*errmsg) return;
  csswap(csu,cset1);
  freecharset(csu);
}


void csremove(charset *cset1, const charset *cset2, errmsg_t errmsg)
{
  charset *csu;

  csu = csdiff(cset1,cset2,errmsg);
  if (*errmsg) return;
  csswap(csu,cset1);
  freecharset(csu);
}


charset *cscopy(const charset *cset, errmsg_t errmsg)
{
  charset emptycharset = { NULL, NULL, 0 };

  return csunion(cset, &emptycharset, errmsg);
}


void csswap(charset *cset1, charset *cset2)
{
  charset tmp;

  tmp = *cset1;
  *cset1 = *cset2;
  *cset2 = tmp;
}
