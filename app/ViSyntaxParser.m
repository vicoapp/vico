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

#import <sys/time.h>
#import "ViSyntaxParser.h"
#import "ViScope.h"
#import "NSArray-patterns.h"
#import "ViCommon.h"
#import "logging.h"

@interface ViSyntaxParser ()
- (void)updateScopeRangesInRange:(NSRange)updateRange;
@end

@implementation ViSyntaxParser

+ (ViSyntaxParser *)syntaxParserWithLanguage:(ViLanguage *)aLanguage
{
	return [[[ViSyntaxParser alloc] initWithLanguage:aLanguage] autorelease];
}

- (ViSyntaxParser *)initWithLanguage:(ViLanguage *)aLanguage
{
	if ((self = [super init]) != nil) {
		_language = [aLanguage retain];
		_scopeArray = [[NSMutableArray alloc] init];
		_continuations = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	[_context release];
	[_language release];
	[_scopeArray release];
	[_continuations release];
	[super dealloc];
}

- (NSArray *)scopeArray
{
	return _scopeArray;
}

#pragma mark -
#pragma mark Line Continuations

- (void)setContinuation:(NSArray *)continuedMatches forLine:(NSUInteger)lineno
{
	if (continuedMatches) {
		DEBUG(@"setting continuation matches at line %u to %@", lineno, continuedMatches);
		while ([_continuations count] < lineno)
			[_continuations addObject:[NSArray array]];
		[_continuations replaceObjectAtIndex:(lineno - 1) withObject:continuedMatches];
	}
}

- (NSArray *)continuedMatchesForLine:(NSUInteger)lineno
{
	NSArray *continuedMatches = nil;
	if (lineno > 0 && [_continuations count] >= lineno)
		continuedMatches = [_continuations objectAtIndex:(lineno - 1)];
	
	DEBUG(@"continuation scopes at line %u = %@", lineno, continuedMatches);
	return continuedMatches;
}

- (void)pushContinuations:(NSUInteger)changedLines
           fromLineNumber:(NSUInteger)lineNumber
{
	if (lineNumber >= [_continuations count])
		return;

	NSArray *prev;
	if (lineNumber == 0)
		prev = [NSArray array];
	else
		prev = [_continuations objectAtIndex:(lineNumber - 1)];

	DEBUG(@"pushing %i continuations after line %i, copying scopes %@",
	    changedLines, lineNumber, prev);

	while (changedLines-- && lineNumber < [_continuations count])
		[_continuations insertObject:[[prev copy] autorelease] atIndex:lineNumber];
}

- (void)pullContinuations:(NSUInteger)changedLines
           fromLineNumber:(NSUInteger)lineNumber
{
	DEBUG(@"pulling %i continuations at line %i", changedLines, lineNumber);
	while (changedLines-- && lineNumber < [_continuations count])
		[_continuations removeObjectAtIndex:lineNumber];
}

#pragma mark -
#pragma mark Scope mangling

/* Called before the insertion is actually made.
 */
- (void)pushScopes:(NSRange)affectedRange
{
	DEBUG(@"range = %@", NSStringFromRange(affectedRange));

	if (affectedRange.location >= [_scopeArray count])
		return;

	NSRange r;
	ViScope *sleft = [_scopeArray objectAtIndex:affectedRange.location];
	r = [sleft range];
	if (r.location < affectedRange.location && NSMaxRange(r) > affectedRange.location) {
		DEBUG(@"sleft = %@", sleft);
		// must split scope in left and right part
		NSRange rightRange = NSMakeRange(affectedRange.location, NSMaxRange(r) - affectedRange.location);
		ViScope *sright = [ViScope scopeWithScopes:[sleft scopes] range:rightRange];
		NSUInteger j;
		for (j = affectedRange.location; j < NSMaxRange(r); j++)
			[_scopeArray replaceObjectAtIndex:j withObject:sright];
		r.length = affectedRange.location - r.location;
		[sleft setRange:r];
		DEBUG(@"updated sleft = %@", sleft);
		DEBUG(@"sright = %@", sright);
	}

	NSUInteger i = affectedRange.location;
	NSUInteger n = affectedRange.length;
	ViScope *scope = [ViScope scopeWithScopes:[NSArray array] range:affectedRange];
	while (n--)
		[_scopeArray insertObject:scope atIndex:i];

	for (i = NSMaxRange(affectedRange); i < [_scopeArray count];) {
		ViScope *s = [_scopeArray objectAtIndex:i];
		r = [s range];
		r.location += affectedRange.length;
		DEBUG(@"%@ -> %@", s, NSStringFromRange(r));
		[s setRange:r];
		i += r.length;
	}
}

- (void)pullScopes:(NSRange)affectedRange
{
	DEBUG(@"range = %@", NSStringFromRange(affectedRange));

	if (affectedRange.location >= [_scopeArray count])
		return;

	ViScope *sleft = [_scopeArray objectAtIndex:affectedRange.location];
	NSRange r = [sleft range];
	if (NSMaxRange(r) > affectedRange.location) {
		DEBUG(@"sleft = %@", sleft);
		// must update (shorten) length of chopped range
		if (NSMaxRange(r) > NSMaxRange(affectedRange))
			r.length -= affectedRange.length;
		else
			r.length -= NSMaxRange(r) - affectedRange.location;
		[sleft setRange:r];
		DEBUG(@"shortened sleft = %@", sleft);
	}

	if ([_scopeArray count] > NSMaxRange(affectedRange))
	{
		ViScope *sright = [_scopeArray objectAtIndex:NSMaxRange(affectedRange)];
		if (sright != sleft && [sright range].location < NSMaxRange(affectedRange))
		{
			// problem if NSMaxRange(sright) < NSMaxRange(affectedRange) (BUG!)
			if (NSMaxRange([sright range]) <= NSMaxRange(affectedRange))
			{
				DEBUG(@"affectedRange = %@", affectedRange);
				DEBUG(@"sright = %@", sright);
				DEBUG(@"sleft = %@", sleft);
				NSBeep(); sleep(1);
				NSBeep(); sleep(1);
				NSBeep(); sleep(1);
			}
			else
			{
				NSRange xr = NSMakeRange(NSMaxRange(affectedRange), NSMaxRange([sright range]) - NSMaxRange(affectedRange));
				DEBUG(@"adjusting shortened scope %i:%@ -> %@", NSMaxRange(affectedRange), sright, NSStringFromRange(xr));
				[sright setRange:xr];
			}
		}
	}

	if ([_scopeArray count] <= affectedRange.location)
		return;
	[_scopeArray removeObjectsInRange:NSIntersectionRange(affectedRange, NSMakeRange(0, [_scopeArray count]))];

	NSUInteger i;
	for (i = affectedRange.location; i < [_scopeArray count];)
	{
		ViScope *s = [_scopeArray objectAtIndex:i];
		r = [s range];
		if (r.location > affectedRange.location)
		{
			if (r.location >= affectedRange.length)
				r.location = r.location - affectedRange.length;
			else
				r.location = 0;
			// r.location = i;
			DEBUG(@"%i:%@ -> %@", i, s, NSStringFromRange(r));
			[s setRange:r];
			i += r.length;
		}
		else
		{
			DEBUG(@"skipping adjusting %i:%@", i, s);
			i += r.length - (i - r.location);
		}
	}
}

- (void)setScopes:(NSArray *)aScopeArray inRange:(NSRange)aRange additive:(BOOL)additive
{
	NSUInteger c = [aScopeArray count];
	if (c == 0 || aRange.length == 0 || aRange.location > [_scopeArray count])
		return;

	DEBUG(@"-- got scope [%@] in range %@", [aScopeArray componentsJoinedByString:@" "], NSStringFromRange(aRange));

	ViScope *scope = nil;
	if (!additive)
		scope = [ViScope scopeWithScopes:aScopeArray range:aRange];

	NSUInteger i;
	for (i = aRange.location; i < NSMaxRange(aRange); i++) {
		if (additive) {
			NSArray *oldScopes = [[_scopeArray objectAtIndex:i] scopes];
			scope = [ViScope scopeWithScopes:[oldScopes arrayByAddingObjectsFromArray:aScopeArray] range:NSMakeRange(i, 1)];
		}

		if (i == [_scopeArray count])
			[_scopeArray insertObject:scope atIndex:i];
		else
			[_scopeArray replaceObjectAtIndex:i withObject:scope];
	}
}

- (void)updateScopeRangesInRange:(NSRange)updateRange
{
	DEBUG(@"updating scope ranges in range %@", NSStringFromRange(updateRange));

	if (updateRange.location >= [_scopeArray count])
		return;

	NSMutableSet *set = [NSMutableSet set];

	NSUInteger i;
	NSRange beginRange;
	ViScope *begin = [_scopeArray objectAtIndex:updateRange.location];

	// backtrack the first match to get the range right
	i = updateRange.location;
	for (;;)
	{
		ViScope *s = [_scopeArray objectAtIndex:i];
		if (s != begin && ![[begin scopes] isEqualToStringArray:[s scopes]])
		{
			i++;
			NSRange r = [s range];
			if (NSMaxRange(r) > i)
			{
				NSRange newRange = NSMakeRange(r.location, i - r.location);
				DEBUG(@"adjusting prev scope %@ -> %@", s, NSStringFromRange(newRange));
				[s setRange:newRange];
				[set addObject:s];
			}
			break;
		}
		if (s != begin)
			[_scopeArray replaceObjectAtIndex:i withObject:begin];
		if (i == 0)
			break;
		--i;
	}

	beginRange = NSMakeRange(i, updateRange.location - i);
	DEBUG(@"beginRange = %@, begin = %@", NSStringFromRange(beginRange), begin);

	for (i = updateRange.location; i < [_scopeArray count]; i++) {
		ViScope *s = [_scopeArray objectAtIndex:i];
		if (s == begin || [[begin scopes] isEqualToStringArray:[s scopes]]) {
			beginRange.length++;
			if (s != begin)
				[_scopeArray replaceObjectAtIndex:i withObject:begin];
		} else if (i >= NSMaxRange(updateRange) && [s range].location == i) {
			DEBUG(@"stopping at %i: %@", i, s);
			NSRange r = [s range];
			if (r.location < i) {
				[s setRange:NSMakeRange(i, NSMaxRange(r) - i)];
				DEBUG(@"adjusting scope at %i: %@", i, s);
			}
			break;
		} else {
			if (begin) {
				[begin setRange:beginRange];
				DEBUG(@"%@", begin);
				[set addObject:begin];
			}
			begin = s;
			beginRange = NSMakeRange(i, 1);
			if ([set containsObject:begin]) {
				begin = [ViScope scopeWithScopes:[s scopes] range:[s range]];
				[_scopeArray replaceObjectAtIndex:i withObject:begin];
			}
		}
	}

	if (begin) {
		[begin setRange:beginRange];
		DEBUG(@"%@", begin);
	}

	DEBUG(@"%s", "done");

#if 0
	gettimeofday(&stop_time, NULL);
	timersub(&stop_time, &start, &diff);
	unsigned ms = diff.tv_sec * 1000 + diff.tv_usec / 1000;
	DEBUG(@"=> %.3f s", (float)ms / 1000.0);
#endif
}

#pragma mark -
#pragma mark Syntax parsing

- (void)highlightCaptures:(NSString *)captureType
                inPattern:(NSDictionary *)pattern
                withMatch:(ViRegexpMatch *)aMatch
{
	NSDictionary *captures = [pattern objectForKey:captureType];
	if (captures == nil)
		captures = [pattern objectForKey:@"captures"];
	if (captures == nil)
		return;

	NSString *key;
	for (key in [captures allKeys]) {
		NSDictionary *capture = [captures objectForKey:key];
		NSRange r = [aMatch rangeOfSubstringAtIndex:[key intValue]];
		if (r.length > 0) {
			DEBUG(@"got capture [%@] at %u + %u", [capture objectForKey:@"name"], r.location, r.length);
			[self setScopes:[NSArray arrayWithObject:[capture objectForKey:@"name"]] inRange:r additive:YES];
		}
	}
}

- (void)highlightBeginCapturesInMatch:(ViSyntaxMatch *)aMatch
{
	[self highlightCaptures:@"beginCaptures" inPattern:[aMatch pattern] withMatch:[aMatch beginMatch]];
}

- (void)highlightEndCapturesInMatch:(ViSyntaxMatch *)aMatch
{
	[self highlightCaptures:@"endCaptures" inPattern:[aMatch pattern] withMatch:[aMatch endMatch]];
}

- (void)highlightCapturesInMatch:(ViSyntaxMatch *)aMatch
{
	[self highlightCaptures:@"captures" inPattern:[aMatch pattern] withMatch:[aMatch beginMatch]];
}

- (NSArray *)endMatchesForBeginMatch:(ViSyntaxMatch *)beginMatch inRange:(NSRange)aRange
{
	DEBUG(@"searching for end match to [%@] in range %u + %u",
	      [beginMatch scope], aRange.location, aRange.length);

	ViRegexp *endRegexp = [beginMatch endRegexp];
	if (endRegexp == nil) {
		endRegexp = [_language compileRegexp:[[beginMatch pattern] objectForKey:@"end"]
			  withBackreferencesToRegexp:[beginMatch beginMatch]
					   matchText:_chars];
	}

	if (endRegexp == nil) {
		DEBUG(@"%s", "!!!!!!!!! no end regexp?");
		return nil;
	}

	// get all matches, one might be overlapped by a subpattern
	NSArray *matches = nil;
	aRange.location -= _offset;
	matches = [endRegexp allMatchesInCharacters:_chars range:aRange start:_offset];

#ifdef STATISTICS
	_regexps_tried++;
	_regexps_matched += [matches count];
#endif

	return matches;
}

- (NSArray *)applyPatterns:(NSArray *)patterns
		   inRange:(NSRange)aRange
	       openMatches:(NSArray *)openMatches
		reachedEOL:(BOOL *)reachedEOL
{
	if (reachedEOL)
		*reachedEOL = NO;

	if (aRange.length == 0)
	{
		DEBUG(@"=============== detected zero-length range %u + %u", aRange.location, aRange.length);
		goto done;
	}

	DEBUG(@"searching %i patterns in range %u + %u", [patterns count], aRange.location, aRange.length);

	NSArray *topScopes = [self scopesFromMatches:openMatches withoutContentForMatch:nil];

	// keep an array of matches so we can sort it in order to skip overlapping matches
	NSMutableArray *matchingPatterns = [NSMutableArray array];
	NSMutableDictionary *pattern;

	ViSyntaxMatch *topOpenMatch = [openMatches lastObject];
	if (topOpenMatch) {
		NSArray *endMatches = [self endMatchesForBeginMatch:topOpenMatch inRange:aRange];
		DEBUG(@"found %u possible end matches to scope [%@]", [endMatches count], [topOpenMatch scope]);
		for (ViRegexpMatch *match in endMatches) {
			ViSyntaxMatch *m = [[ViSyntaxMatch alloc] initWithMatch:match andPattern:[topOpenMatch pattern] atIndex:0];
			[m setEndMatch:match];
			[matchingPatterns addObject:m];
			[m release];
		}
	}

	NSRange rxRange = NSMakeRange(aRange.location - _offset, aRange.length);
	int i = 0; // patterns in textmate bundles are ordered so we need to keep track of the index in the patterns array
	for (pattern in patterns) {
		/* Match all patterns against this range.
		 */
		ViRegexp *regexp = [pattern objectForKey:@"matchRegexp"];
		if (regexp == nil)
			regexp = [pattern objectForKey:@"beginRegexp"];
		if (regexp == nil)
			continue;
		NSArray *matches;
		matches = [regexp allMatchesInCharacters:_chars range:rxRange start:_offset];

#ifdef STATISTICS
		_regexps_tried++;
		_regexps_matched += [matches count];
#endif

		if ([matches count] == 0)
			DEBUG(@"  matching against pattern %@", [pattern objectForKey:@"name"]);
		else
			DEBUG(@"  matching against pattern %@ = %i matches",
			    [pattern objectForKey:@"name"], [matches count]);

		for (ViRegexpMatch *match in matches) {
			ViSyntaxMatch *viMatch = [[ViSyntaxMatch alloc] initWithMatch:match
									   andPattern:pattern
									      atIndex:i];
			[matchingPatterns addObject:viMatch];
			[viMatch release];
		}

		++i;
	}
	[matchingPatterns sortUsingSelector:@selector(sortByLocation:)];

	DEBUG(@"applying %u matches in range %u + %u",
	    [matchingPatterns count], aRange.location, aRange.length);
	NSUInteger lastLocation = aRange.location;
	for (ViSyntaxMatch *aMatch in matchingPatterns) {
		if ([aMatch beginLocation] < lastLocation) {
			// skip overlapping matches
#ifdef STATISTICS
			_regexps_overlapped++;
#endif
			DEBUG(@"skipping overlapping match for [%@] at %u + %u",
			    [aMatch scope], [aMatch beginLocation], [aMatch beginLength]);
			continue;
		}

		if ([aMatch beginLocation] > lastLocation) {
			// Apply current scopes before adding the new match
			[self setScopes:topScopes
				inRange:NSMakeRange(lastLocation, [aMatch beginLocation] - lastLocation)
			       additive:NO];
		}

		if ([aMatch isSingleLineMatch]) {
			DEBUG(@"got match on [%@] at %u + %u (subpattern)",
			      [aMatch scope],
			      [[aMatch beginMatch] rangeOfMatchedString].location,
			      [[aMatch beginMatch] rangeOfMatchedString].length);
			[self setScopes:topScopes inRange:[aMatch matchedRange] additive:NO];
			if ([aMatch scope])
				[self setScopes:[NSArray arrayWithObject:[aMatch scope]] inRange:[aMatch matchedRange] additive:YES];
			/* We might not have a scope for the whole match. There is probably only captures, which is ok. */
			[self highlightCapturesInMatch:aMatch];
		} else if ([aMatch endMatch]) {
			ViRegexpMatch *endMatch = [aMatch endMatch];
			[topOpenMatch setEndMatch:endMatch];
			DEBUG(@"got end match on [%@] at %u + %u",
			      [aMatch scope],
			      [endMatch rangeOfMatchedString].location,
			      [endMatch rangeOfMatchedString].length);

			topScopes = [self scopesFromMatches:openMatches withoutContentForMatch:topOpenMatch];
			[self setScopes:topScopes inRange:[endMatch rangeOfMatchedString] additive:NO];
			[self highlightEndCapturesInMatch:aMatch];

			// pop one or more open matches off the stack and return the rest
			while ([openMatches count] > 0) {
				openMatches = [openMatches subarrayWithRange:NSMakeRange(0, [openMatches count] - 1)];
				topOpenMatch = [openMatches lastObject];
				if (topOpenMatch == nil)
					break;
#if 0
				NSArray *endMatches = [self endMatchesForBeginMatch:topOpenMatch inRange:[endMatch rangeOfMatchedString]];
				/*
				 * Disabled the loop as it breaks the Java bundle.
				 * I don't remember what the loop actually fixed,
				 * so we're probably still doing something wrong here.
				 */
				// if the next top open match also matches the end range,
				// and it is a look-ahead match, keep popping off open matches
				if (endMatches == nil || [[endMatches objectAtIndex:0] rangeOfMatchedString].length != 0)
					break;
#endif
				break;
			}

			DEBUG(@"returning %i continuation matches", [openMatches count]);
			return [openMatches count] > 0 ? openMatches : nil;
		} else {
			DEBUG(@"got begin match on [%@] at %u + %u", [aMatch scope], [aMatch beginLocation], [aMatch beginLength]);
			NSArray *newTopScopes = [aMatch scope] ? [topScopes arrayByAddingObject:[aMatch scope]] : topScopes;
			[self setScopes:newTopScopes inRange:[[aMatch beginMatch] rangeOfMatchedString] additive:NO];
			// search for end match from after the begin match to EOL
			NSRange range = aRange;
			range.location = NSMaxRange([[aMatch beginMatch] rangeOfMatchedString]);
			range.length = NSMaxRange(aRange) - range.location;
			logIndent++;
			BOOL tmpEOL = NO;
			NSArray *continuationMatches = [self applyPatterns:[_language expandedPatternsForPattern:[aMatch pattern]]
								   inRange:range
							       openMatches:[openMatches arrayByAddingObject:aMatch]
								reachedEOL:&tmpEOL];
			logIndent--;
			// need to highlight captures _after_ the main pattern has been highlighted
			[self highlightBeginCapturesInMatch:aMatch];
			if (tmpEOL == YES) {
				if (reachedEOL)
					*reachedEOL = YES;
				DEBUG(@"returning %i continuation matches", [continuationMatches count]);
				return continuationMatches;
			}
		}

		lastLocation = [aMatch endLocation];
		// just stop if we passed our line range
		if (lastLocation >= NSMaxRange(aRange)) {
			DEBUG(@"%s", "skipping further matches as we passed our line range");
			break;
		}
	}

	if (lastLocation < NSMaxRange(aRange))
		[self setScopes:topScopes inRange:NSMakeRange(lastLocation, NSMaxRange(aRange) - lastLocation) additive:NO];

done:
	if (reachedEOL)
		*reachedEOL = YES;

	if (openMatches) {
		DEBUG(@"returning %i continuation matches", [openMatches count]);
		return openMatches;
	}
	return nil;
}

- (NSArray *)scopesFromMatches:(NSArray *)matches withoutContentForMatch:(ViSyntaxMatch *)skipContentMatch
{
	NSMutableArray *scopes = [[NSMutableArray alloc] initWithCapacity:[matches count] + 1];
	if ([[_language name] length] > 0)
		[scopes addObject:[_language name]];
	for (ViSyntaxMatch *m in matches) {
		if ([[m scope] length] > 0)
			[scopes addObject:[m scope]];
		if (m != skipContentMatch) {
			NSString *contentName = [[m pattern] objectForKey:@"contentName"];
			if ([contentName length] > 0)
				[scopes addObject:contentName];
		}
	}

	DEBUG(@"got scopes [%@]", [scopes componentsJoinedByString:@" "]);
	return [scopes autorelease];
}

- (NSArray *)highlightLineInRange:(NSRange)aRange
              continueWithMatches:(NSArray *)continuedMatches
{
	DEBUG(@"-----> line range = %u (%u) + %u",
	    aRange.location, aRange.location, aRange.length);

	// should we continue on multi-line matches?
	BOOL reachedEOL = NO;
	while ([continuedMatches count] > 0) {
		DEBUG(@"continuing with match [%@] (of %i total) at %@",
		    [[continuedMatches lastObject] scope],
		    [continuedMatches count], NSStringFromRange(aRange));

		for (ViSyntaxMatch *m in continuedMatches)
			[m setBeginLocation:aRange.location];

		ViSyntaxMatch *topMatch = [continuedMatches lastObject];

		continuedMatches = [self applyPatterns:[_language expandedPatternsForPattern:[topMatch pattern]]
					       inRange:aRange
					   openMatches:continuedMatches
					    reachedEOL:&reachedEOL];

		if (reachedEOL)
			return continuedMatches;
		NSUInteger lastLocation = [topMatch endLocation];

		// adjust the line range
		if (lastLocation >= NSMaxRange(aRange))
			return nil;
		aRange.length = NSMaxRange(aRange) - lastLocation;
		aRange.location = lastLocation;
	}

	// search top-level patterns
	return [self applyPatterns:[_language patterns]
	                   inRange:aRange
	               openMatches:[NSArray array]
	                reachedEOL:nil];
}

- (void)parseContext:(ViSyntaxContext *)aContext
{
#ifdef STATISTICS
	struct timeval start;
	struct timeval stop_time;
	struct timeval diff;
	gettimeofday(&start, NULL);

	_regexps_tried = 0;
	_regexps_overlapped = 0;
	_regexps_matched = 0;
	_regexps_cached = 0;
#endif

	[_context release];
	_context = [aContext retain];

	_offset = _context.range.location;
	_chars = _context.characters;
	NSUInteger lineno = _context.lineOffset;

	DEBUG(@"parsing line %u (%u -> %u)",
		_context.lineOffset,
		_context.range.location,
		NSMaxRange(_context.range));

	NSArray *continuedMatches = [self continuedMatchesForLine:lineno - 1];

	NSUInteger nextRange = _offset;
	NSUInteger maxRange = NSMaxRange(_context.range);

	// highlight each line separately
	for (;;)
	{
		unichar ch = '\0';
		NSUInteger end = nextRange;
		while (end < maxRange && (ch = _chars[end - _offset]) != '\n' && ch != '\r')
			++end;
		if (ch == '\r' && end + 1 < maxRange && _chars[end + 1 - _offset] == '\n')
			++end;
		if (end < maxRange)
			++end;
		if (end > maxRange)
			end = NSNotFound;

		if (end == nextRange || end == NSNotFound)
			break;

		NSRange line = NSMakeRange(nextRange, end - nextRange);
		if (line.length > 3000) {
			/* Extremely large lines result in beachballing. */
			NSRange overflow = NSMakeRange(line.location + 3000, line.length - 3000);
			[self setScopes:[NSArray arrayWithObject:_language.name]
			        inRange:overflow
			       additive:NO];
			line.length = 3000;
		}

		DEBUG(@"---> line number %i (%u -> %u, w/offset %u, length %u)",
		    lineno, nextRange, end, _offset, end - nextRange);

		continuedMatches = [self highlightLineInRange:line continueWithMatches:continuedMatches];
		nextRange = end;

		NSArray *endMatches = [self continuedMatchesForLine:lineno];
		BOOL equalMatches = (endMatches && [continuedMatches isEqualToPatternArray:endMatches]);
		[self setContinuation:continuedMatches forLine:lineno];
		// endMatches is now replaced and invalid (released)
		endMatches = nil;

		if (nextRange >= maxRange) {
			if (!equalMatches) {
				DEBUG(@"detected changed line end matches in incremental mode at line %u", lineno);
				/* Signal that we must continue re-parsing lines following this line.
				 */
				_context.lineOffset = lineno + 1;
			}
			break;
		} else if (_context.restarting) {
			if (equalMatches) {
				DEBUG(@"detected matching line end matches, stopping at line %u", lineno);
				break;
			}
		}

		lineno++;
	}

#ifdef STATISTICS
	gettimeofday(&stop_time, NULL);
	timersub(&stop_time, &start, &diff);
	unsigned ms = diff.tv_sec * 1000 + diff.tv_usec / 1000;
	DEBUG(@"regexps tried: %u, matched: %u, overlapped: %u, cached: %u  => %u lines in %.3f s",
		_regexps_tried, _regexps_matched, _regexps_overlapped, _regexps_cached, lineno + 1, (float)ms / 1000.0);
#endif

	[_context setRange:NSMakeRange(_offset, nextRange - _offset)];
	_chars = NULL;

	[self updateScopeRangesInRange:[_context range]];
	[_context release];
	_context = nil;
}

@end

