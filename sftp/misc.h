/* $OpenBSD: misc.h,v 1.38 2008/06/12 20:38:28 dtucker Exp $ */

/*
 * Author: Tatu Ylonen <ylo@cs.hut.fi>
 * Copyright (c) 1995 Tatu Ylonen <ylo@cs.hut.fi>, Espoo, Finland
 *                    All rights reserved
 *
 * As far as I am concerned, the code I have written for this software
 * can be used freely for any purpose.  Any derived versions of this
 * software must be clearly marked as such, and if the derived work is
 * incompatible with the protocol description in the RFC file, it must be
 * called by a name other than "ssh" or "Secure Shell".
 */

#ifndef _MISC_H
#define _MISC_H

/* misc.c */

/* Functions to extract or store big-endian words of various sizes */
u_int64_t	get_u64(const void *);
    //__attribute__((__bounded__( __minbytes__, 1, 8)));
u_int32_t	get_u32(const void *);
    //__attribute__((__bounded__( __minbytes__, 1, 4)));
u_int16_t	get_u16(const void *);
    //__attribute__((__bounded__( __minbytes__, 1, 2)));
void		put_u64(void *, u_int64_t);
    //__attribute__((__bounded__( __minbytes__, 1, 8)));
void		put_u32(void *, u_int32_t);
    //__attribute__((__bounded__( __minbytes__, 1, 4)));
void		put_u16(void *, u_int16_t);
    //__attribute__((__bounded__( __minbytes__, 1, 2)));

#endif /* _MISC_H */
