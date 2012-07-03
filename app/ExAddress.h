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

enum ExAddressType {
	ExAddressNone,
	ExAddressAbsolute,
	ExAddressSearch,
	ExAddressMark,
	ExAddressCurrent,
	ExAddressRelative
};

@interface ExAddress : NSObject <NSCopying>
{
	enum ExAddressType	 _type;
	NSInteger		 _offset;
	NSInteger		 _line;
	NSString		*_pattern;
	BOOL			 _backwards;
	unichar			 _mark;
}

@property(nonatomic,readwrite) enum ExAddressType type;
@property(nonatomic,readwrite) NSInteger offset;
@property(nonatomic,readwrite) NSInteger line;
@property(nonatomic,readwrite,copy) NSString *pattern;
@property(nonatomic,readwrite) BOOL backwards;
@property(nonatomic,readwrite) unichar mark;

+ (ExAddress *)address;

@end
