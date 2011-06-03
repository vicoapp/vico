/***********************/
/* errmsg.h            */
/* for Par 1.52-i18n.3 */
/* Copyright 2001 by   */
/* Adam M. Costello    */
/* Modified by         */
/* Jérôme Pouiller     */
/***********************/

/* This is ANSI C code (C89). */


#ifndef ERRMSG_H
#define ERRMSG_H

#include <wchar.h>
#define errmsg_size 163

/* This is the maximum number of characters that will  */
/* fit in an errmsg_t, including the terminating '\0'. */
/* It will never decrease, but may increase in future  */
/* versions of this header file.                       */


typedef wchar_t errmsg_t[errmsg_size];

/* Any function which takes the argument errmsg_t errmsg must, before */
/* returning, either set errmsg[0] to '\0' (indicating success), or   */
/* write an error message string into errmsg, (indicating failure),   */
/* being careful not to overrun the space.                            */


extern const wchar_t * const outofmem;
  /* "Out of memory.\n" */

extern const wchar_t * const mbserror;
  /* "Error in input multibyte string.\n" */
  
extern const wchar_t * const impossibility;
  /* "Impossibility #%d has occurred.  Please report it.\n" */


#endif
