/***********************/
/* errmsg.c            */
/* for Par 1.52-i18n.3 */
/* Copyright 2001 by   */
/* Adam M. Costello    */
/* Modified by         */
/* Jérôme Pouiller     */
/***********************/

/* This is ANSI C code (C89). */


#include "errmsg.h"  /* Makes sure we're consistent with the declarations. */


const wchar_t * const outofmem =
  L"Out of memory.\n";

const wchar_t * const mbserror =
  L"Error in input multibyte string.\n";

const wchar_t * const impossibility =
  L"Impossibility #%d has occurred.  Please report it.\n";
