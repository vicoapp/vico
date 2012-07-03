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

#import "NSArray-patterns.h"
#import "NSString-scopeSelector.h"
#import "ViSyntaxMatch.h"

@implementation NSArray (patterns)

- (BOOL)isEqualToPatternArray:(NSArray *)otherArray
{
	NSUInteger i, c = [self count];
	if (otherArray == self)
		return YES;
	if (c != [otherArray count])
		return NO;
	for (i = 0; i < c; i++)
		if ([[self objectAtIndex:i] pattern] != [[otherArray objectAtIndex:i] pattern])
			return NO;
	return YES;
}

- (BOOL)isEqualToStringArray:(NSArray *)otherArray
{
	NSInteger i, c = [self count];
	if (otherArray == self)
		return YES;
	if (c != [otherArray count])
		return NO;
	for (i = c - 1; i >= 0; i--)
		if (![[self objectAtIndex:i] isEqualToString:[otherArray objectAtIndex:i]])
			return NO;
	return YES;
}

- (BOOL)hasPrefix:(NSArray *)otherArray
{
	if ([self count] < [otherArray count])
		return NO;

	for (NSUInteger i = 0; i < [otherArray count]; i++)
		if (![[self objectAtIndex:i] isEqual:[otherArray objectAtIndex:i]])
			return NO;

	return YES;
}

- (BOOL)hasSuffix:(NSArray *)otherArray
{
	NSInteger j = [self count] - [otherArray count];
	if (j < 0)
		return NO;

	for (NSInteger i = 0; i < [otherArray count]; i++)
		if (![[self objectAtIndex:j] isEqual:[otherArray objectAtIndex:i]])
			return NO;

	return YES;
}

@end

