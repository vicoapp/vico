/***********************/
/* buffer.h            */
/* for Par 1.52-i18n.3 */
/* Copyright 2001 by   */
/* Adam M. Costello    */
/***********************/

/* This is ANSI C code (C89). */


/* Note: Those functions declared here which do not use errmsg    */
/* always succeed, provided that they are passed valid arguments. */


#include "errmsg.h"

#include <stddef.h>


typedef struct buffer buffer;


buffer *newbuffer(size_t itemsize, errmsg_t errmsg);

  /* newbuffer(itemsize,errmsg) returns a pointer to a    */
  /* new empty buffer which holds items of size itemsize. */
  /* itemsize must not be 0.  Returns NULL on failure.    */


void freebuffer(buffer *buf);

  /* freebuffer(buf) frees the memory associated with */
  /* *buf.  buf may not be used after this call.      */


void clearbuffer(buffer *buf);

  /* clearbuffer(buf) removes  */
  /* all items from *buf, but  */
  /* does not free any memory. */


void additem(buffer *buf, const void *item, errmsg_t errmsg);

  /* additem(buf,item,errmsg) copies *item to the end of     */
  /* *buf.  item must point to an object of the proper size  */
  /* for *buf.  If additem() fails, *buf will be unaffected. */


int numitems(buffer *buf);

  /* numitems(buf) returns the number of items in *buf. */


void *copyitems(buffer *buf, errmsg_t errmsg);

  /* copyitems(buf,errmsg) returns an array of objects of */
  /* the proper size for *buf, one for each item in *buf, */
  /* or NULL if there are no items in buf.  The elements  */
  /* of the array are copied from the items in *buf, in   */
  /* order.  The array is allocated with malloc(), so it  */
  /* may be freed with free().  Returns NULL on failure.  */


void *nextitem(buffer *buf);

  /* When buf was created by newbuffer, a pointer associated with buf  */
  /* was initialized to point at the first slot in *buf.  If there is  */
  /* an item in the slot currently pointed at, nextitem(buf) advances  */
  /* the pointer to the next slot and returns the old value.  If there */
  /* is no item in the slot, nextitem(buf) leaves the pointer where it */
  /* is and returns NULL.                                              */


void rewindbuffer(buffer *buf);

  /* rewindbuffer(buf) resets the pointer used by   */
  /* nextitem() to point at the first slot in *buf. */
