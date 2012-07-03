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

#import "ViSyntaxMatch.h"

@implementation ViSyntaxMatch

@synthesize patternIndex = _patternIndex;
@synthesize pattern = _pattern;
@synthesize beginLocation = _beginLocation;
@synthesize beginLength = _beginLength;
@synthesize beginMatch = _beginMatch;
@synthesize endMatch = _endMatch;

- (id)initWithMatch:(ViRegexpMatch *)aMatch andPattern:(NSMutableDictionary *)aPattern atIndex:(int)i
{
	if ((self = [super init]) != nil) {
		_beginMatch = [aMatch retain];
		_pattern = [aPattern retain];
		_patternIndex = i;
		if (aMatch) {
			_beginLocation = [aMatch rangeOfMatchedString].location;
			_beginLength = [aMatch rangeOfMatchedString].length;
		}
	}
	return self;
}

- (void)dealloc
{
	[_beginMatch release];
	[_endMatch release];
	[_pattern release];
	[super dealloc];
}

- (NSComparisonResult)sortByLocation:(ViSyntaxMatch *)anotherMatch
{
	if (_beginLocation < anotherMatch.beginLocation)
		return NSOrderedAscending;
	if (_beginLocation > anotherMatch.beginLocation)
		return NSOrderedDescending;
	if (_patternIndex < anotherMatch.patternIndex)
		return NSOrderedAscending;
	if (_patternIndex > anotherMatch.patternIndex)
		return NSOrderedDescending;
	return NSOrderedSame;
}

- (ViRegexp *)endRegexp
{
	return [_pattern objectForKey:@"endRegexp"];
}

- (void)setBeginLocation:(NSUInteger)aLocation
{
	// used for continued multi-line matches
	_beginLocation = aLocation;
	_beginLength = 0;
}

- (NSUInteger)endLocation
{
	if (_endMatch)
		return NSMaxRange([_endMatch rangeOfMatchedString]);
	else
		return NSMaxRange([_beginMatch rangeOfMatchedString]); // FIXME: ???
}

- (NSString *)scope
{
	return [_pattern objectForKey:@"name"];
}

- (NSRange)matchedRange
{
	return NSMakeRange(_beginLocation, [self endLocation] - _beginLocation);
}

- (BOOL)isSingleLineMatch
{
	return [_pattern objectForKey:@"begin"] == nil;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViSyntaxMatch: scope = %@>", [self scope]];
}

@end

