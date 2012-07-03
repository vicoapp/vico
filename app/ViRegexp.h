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

#include <oniguruma.h>

@interface ViRegexpMatch : NSObject
{
	OnigRegion	*_region;
	NSUInteger	 _startLocation;
}

@property(nonatomic,readonly) NSUInteger startLocation;

+ (ViRegexpMatch *)regexpMatchWithRegion:(OnigRegion *)aRegion startLocation:(NSUInteger)aLocation;
- (ViRegexpMatch *)initWithRegion:(OnigRegion *)aRegion startLocation:(NSUInteger)aLocation;
- (NSRange)rangeOfMatchedString;
- (NSRange)rangeOfSubstringAtIndex:(NSUInteger)index;
- (NSUInteger)count;

@end


@interface ViRegexp : NSObject
{
	NSString	*_pattern;
	OnigRegex	 _regex;
}

+ (BOOL)shouldIgnoreCaseForString:(NSString *)string;
+ (NSInteger)defaultOptionsForString:(NSString *)string;
+ (NSCharacterSet *)reservedCharacters;
+ (BOOL)needEscape:(unichar)ch;
+ (NSString *)escape:(NSString *)string inRange:(NSRange)range;
+ (NSString *)escape:(NSString *)string;

+ (ViRegexp *)regexpWithString:(NSString *)aString;
+ (ViRegexp *)regexpWithString:(NSString *)aString options:(NSInteger)options;
+ (ViRegexp *)regexpWithString:(NSString *)aString options:(NSInteger)options error:(NSError **)outError;

- (ViRegexp *)initWithString:(NSString *)aString;
- (ViRegexp *)initWithString:(NSString *)aString options:(NSInteger)options;
- (ViRegexp *)initWithString:(NSString *)aString options:(NSInteger)options error:(NSError **)outError;
- (BOOL)matchesString:(NSString *)aString;
- (ViRegexpMatch *)matchInString:(NSString *)aString range:(NSRange)aRange options:(NSInteger)options;
- (ViRegexpMatch *)matchInString:(NSString *)aString range:(NSRange)aRange;
- (ViRegexpMatch *)matchInString:(NSString *)aString;
- (ViRegexpMatch *)matchInCharacters:(const unichar *)chars range:(NSRange)aRange start:(NSUInteger)aLocation;
- (ViRegexpMatch *)matchInCharacters:(const unichar *)chars options:(NSInteger)options range:(NSRange)aRange start:(NSUInteger)aLocation;
- (NSArray *)allMatchesInCharacters:(const unichar *)chars options:(NSInteger)options range:(NSRange)aRange start:(NSUInteger)aLocation;
- (NSArray *)allMatchesInCharacters:(const unichar *)chars range:(NSRange)aRange start:(NSUInteger)aLocation;
- (NSArray *)allMatchesInString:(NSString *)aString range:(NSRange)aRange;
- (NSArray *)allMatchesInString:(NSString *)aString options:(NSInteger)options;
- (NSArray *)allMatchesInString:(NSString *)aString options:(NSInteger)options range:(NSRange)aRange;
- (NSArray *)allMatchesInString:(NSString *)aString range:(NSRange)aRange start:(NSUInteger)aLocation;
- (NSArray *)allMatchesInString:(NSString *)aString;

@end

