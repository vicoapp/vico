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

#import "ExAddress.h"

@implementation ExAddress

@synthesize type = _type;
@synthesize offset = _offset;
@synthesize line = _line;
@synthesize pattern = _pattern;
@synthesize backwards = _backwards;
@synthesize mark = _mark;

- (id)copyWithZone:(NSZone *)zone
{
	ExAddress *copy = [[[self class] allocWithZone:zone] init];
	copy.type = _type;
	copy.offset = _offset;
	copy.line = _line;
	copy.pattern = _pattern;
	copy.mark = _mark;
	return copy;
}

+ (ExAddress *)address
{
	return [[[ExAddress alloc] init] autorelease];
}

- (void)dealloc
{
	[_pattern release];
	[super dealloc];
}

- (NSString *)description
{
	switch (_type) {
	default:
	case ExAddressNone:
		return [NSString stringWithFormat:@"<ExAddress %p: none>", self, _offset];
	case ExAddressAbsolute:
		return [NSString stringWithFormat:@"<ExAddress %p: line %li, offset %li>", self, _line, _offset];
	case ExAddressSearch:
		return [NSString stringWithFormat:@"<ExAddress %p: pattern %@, offset %li>", self, _pattern, _offset];
	case ExAddressMark:
		return [NSString stringWithFormat:@"<ExAddress %p: mark %C, offset %li>", self, _mark, _offset];
	case ExAddressCurrent:
		return [NSString stringWithFormat:@"<ExAddress %p: current line, offset %li>", self, _offset];
	case ExAddressRelative:
		return [NSString stringWithFormat:@"<ExAddress %p: relative, offset %li>", self, _offset];
	}
}

@end
