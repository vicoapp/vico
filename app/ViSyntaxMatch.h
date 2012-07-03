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

#import "ViRegexp.h"

@interface ViSyntaxMatch : NSObject
{
	ViRegexpMatch		*_beginMatch;
	ViRegexpMatch		*_endMatch;
	NSMutableDictionary	*_pattern;
	int			 _patternIndex;
	NSUInteger		 _beginLocation;
	NSUInteger		 _beginLength;
}

@property(nonatomic,readonly) int patternIndex;
@property(nonatomic,readonly) NSMutableDictionary *pattern;
@property(nonatomic,readwrite) NSUInteger beginLocation;
@property(nonatomic,readonly) NSUInteger beginLength;
@property(nonatomic,readonly) ViRegexpMatch *beginMatch;
@property(nonatomic,readwrite,retain) ViRegexpMatch *endMatch;

- (id)initWithMatch:(ViRegexpMatch *)aMatch andPattern:(NSMutableDictionary *)aPattern atIndex:(int)i;
- (NSComparisonResult)sortByLocation:(ViSyntaxMatch *)match;
- (ViRegexp *)endRegexp;
- (NSUInteger)endLocation;
- (NSString *)scope;
- (NSRange)matchedRange;
- (BOOL)isSingleLineMatch;
- (NSString *)description;

@end

