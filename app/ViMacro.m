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

#import "ViMacro.h"
#import "NSString-additions.h"
#include "logging.h"

@implementation ViMacro

@synthesize mapping = _mapping;

+ (id)macroWithMapping:(ViMapping *)aMapping prefix:(NSArray *)prefixKeys
{
	return [[ViMacro alloc] initWithMapping:aMapping prefix:prefixKeys];
}

- (id)initWithMapping:(ViMapping *)aMapping prefix:(NSArray *)prefixKeys
{
	if ((self = [super init])) {
		_mapping = aMapping;
		_ip = 0;
		_keys = [[aMapping.macro keyCodes] mutableCopy];
		if ([prefixKeys count] > 0)
			[_keys replaceObjectsInRange:NSMakeRange(0, 0) withObjectsFromArray:prefixKeys];
	}

	DEBUG_INIT();
	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
}

- (void)push:(NSNumber *)keyCode
{
	[_keys insertObject:keyCode atIndex:_ip];
}

- (NSInteger)pop
{
	if (_ip >= [_keys count])
		return -1LL;
	return [[_keys objectAtIndex:_ip++] integerValue];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViMacro %p: %@>",
	    self, [NSString stringWithKeySequence:_keys]];
}

@end
