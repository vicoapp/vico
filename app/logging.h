/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _logging_h_
#define _logging_h_

extern int logIndent;

#ifndef FORCE_DEBUG
#define NO_DEBUG
#endif

#ifdef DEBUG
# undef DEBUG
#endif

#ifdef NO_DEBUG
# define DEBUG(fmt, ...)
#else
# define DEBUG(fmt, ...) do { \
		NSString *ws = [@"" stringByPaddingToLength:logIndent*2 withString:@" " startingAtIndex:0]; \
		NSLog([NSString stringWithFormat:@"%s:%u: %@%@", __func__, __LINE__, ws, fmt], ## __VA_ARGS__); \
	} while(0)
#endif

#define INFO(fmt, ...) do { \
		NSString *ws = [@"" stringByPaddingToLength:logIndent*2 withString:@" " startingAtIndex:0]; \
		NSLog([NSString stringWithFormat:@"%s:%u: %@%@", __func__, __LINE__, ws, fmt], ## __VA_ARGS__); \
	} while(0)

#endif

#ifndef FORCE_MEMDEBUG
# define NO_MEMDEBUG
#endif

#ifdef NO_MEMDEBUG
# define MEMDEBUG(fmt, ...)
# define DEBUG_FINALIZE()
# define DEBUG_DEALLOC()
# define DEBUG_INIT()
#else
# define MEMDEBUG INFO
# define DEBUG_DEALLOC() MEMDEBUG(@"%p free", self)
# define DEBUG_INIT() MEMDEBUG(@"%p init", self)
# define DEBUG_FINALIZE()		\
- (void)finalize			\
{					\
	MEMDEBUG(@"%p", self);		\
	[super finalize];		\
}
#endif

