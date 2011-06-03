/***********************/
/* reformat.h          */
/* for Par 1.52-i18n.3 */
/* Copyright 2001 by   */
/* Adam M. Costello    */
/* Modified by         */
/* Jérôme Pouiller     */
/***********************/

/* This is ANSI C code (C89). */


#include "errmsg.h"
#include <wchar.h>

wchar_t **reformat(
  const wchar_t * const *inlines, const wchar_t * const *endline, int afp, int fs,
  int hang, int prefix, int suffix, int width, int cap, int fit, int guess,
  int just, int last, int Report, int touch, errmsg_t errmsg
);
  /* inlines is an array of pointers to input lines, up to but not  */
  /* including endline.  inlines and endline must not be equal.     */
  /* The other parameters are the variables of the same name as     */
  /* described in "par.doc".  reformat(inlines, endline, afp, fs,   */
  /* hang, prefix, suffix, width, cap, fit, guess, just, last,      */
  /* Report, touch, errmsg) returns a NULL-terminated array of      */
  /* pointers to output lines containing the reformatted paragraph, */
  /* according to the specification in "par.doc".  None of the      */
  /* integer parameters may be negative.  Returns NULL on failure.  */
