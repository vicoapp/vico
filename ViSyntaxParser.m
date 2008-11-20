#import <sys/time.h>
#import "ViSyntaxParser.h"
#import "ViScope.h"
#import "NSArray-patterns.h"
#import "logging.h"

@implementation ViSyntaxParser

- (ViSyntaxParser *)initWithLanguage:(ViLanguage *)aLanguage
{
	self = [super init];
	if (self)
	{
		language = aLanguage;
		scopeTree = [[MHSysTree alloc] initWithCompareSelector:@selector(compareBegin:)];
		continuations = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)setContinuation:(NSArray *)continuedMatches forLine:(unsigned)lineno
{
	DEBUG(@"setting continuation matches at line %u to %@", lineno, continuedMatches);
	while ([continuations count] < lineno)
	{
		[continuations addObject:[NSArray array]];
	}
	[continuations replaceObjectAtIndex:(lineno - 1) withObject:continuedMatches];
}

- (NSArray *)continuedMatchesForLine:(NSUInteger)lineno
{
	NSArray *continuedMatches = nil;
	if (lineno > 0 && [continuations count] >= lineno)
	{
		continuedMatches = [continuations objectAtIndex:(lineno - 1)];
	}
	
	DEBUG(@"continuation scopes at line %u = %@", lineno, continuedMatches);
	return continuedMatches;
}

- (void)setScopes:(NSArray *)aScopeArray inRange:(NSRange)aRange
{
	int c = [aScopeArray count];
	if (c == 0 || aRange.length == 0)
		return;

	struct rb_entry *e = [scopeTree root];
	while (e)
	{
		ViScope *s = e->obj;
		NSRange r = [s range];
		if (r.location > aRange.location)
		{
			break;
			// FIXME: need to break partially matching scopes here!
			// e = [scopeTree left:e];
		}
		else if (r.location < aRange.location)
		{
			if (NSMaxRange(r) == aRange.location)
			{
				if ([aScopeArray isEqualToStringArray:[s scopes]])
				{
					r.length += aRange.length;
					[s setRange:r];
					return;
				}
			}

			e = [scopeTree right:e];
		}
		else
		{
			if (r.length < aRange.length)
				e = [scopeTree left:e];
			else if (r.length > aRange.length)
			{
				
				e = [scopeTree right:e];
			}
			else
			{
				[s setScopes:aScopeArray];
				return;
			}
		}
	}

	ViScope *scope = [[ViScope alloc] initWithScopes:aScopeArray range:aRange];
	[scopeTree addObject:scope];
	[uglyHack addObject:scope]; // XXX: otherwise garbage collection fucks this up!
}

- (void)highlightCaptures:(NSString *)captureType
                inPattern:(NSDictionary *)pattern
                withMatch:(ViRegexpMatch *)aMatch
                topScopes:(NSArray *)topScopes
{
	NSDictionary *captures = [pattern objectForKey:captureType];
	if (captures == nil)
		captures = [pattern objectForKey:@"captures"];
	if (captures == nil)
		return;

	NSString *key;
	for (key in [captures allKeys])
	{
		NSDictionary *capture = [captures objectForKey:key];
		NSRange r = [aMatch rangeOfSubstringAtIndex:[key intValue]];
		if (r.length > 0)
		{
			DEBUG(@"got capture [%@] at %u + %u", [capture objectForKey:@"name"], r.location, r.length);
			[self setScopes:[topScopes arrayByAddingObject:[capture objectForKey:@"name"]] inRange:r];
		}
	}
}

- (void)highlightBeginCapturesInMatch:(ViSyntaxMatch *)aMatch topScopes:(NSArray *)topScopes
{
	[self highlightCaptures:@"beginCaptures" inPattern:[aMatch pattern] withMatch:[aMatch beginMatch] topScopes:topScopes];
}

- (void)highlightEndCapturesInMatch:(ViSyntaxMatch *)aMatch topScopes:(NSArray *)topScopes
{
	[self highlightCaptures:@"endCaptures" inPattern:[aMatch pattern] withMatch:[aMatch endMatch] topScopes:topScopes];
}

- (void)highlightCapturesInMatch:(ViSyntaxMatch *)aMatch topScopes:(NSArray *)topScopes
{
	[self highlightCaptures:@"captures" inPattern:[aMatch pattern] withMatch:[aMatch beginMatch] topScopes:topScopes];
}

- (NSArray *)endMatchesForBeginMatch:(ViSyntaxMatch *)beginMatch inRange:(NSRange)aRange
{
	DEBUG(@"searching for end match to [%@] in range %u + %u",
	      [beginMatch scope], aRange.location, aRange.length);
	
	ViRegexp *endRegexp = [beginMatch endRegexp];
	if (endRegexp == nil)
	{
		INFO(@"************* => compiling pattern with back references for scope [%@]", [beginMatch scope]);
		endRegexp = [language compileRegexp:[[beginMatch pattern] objectForKey:@"end"]
			 withBackreferencesToRegexp:[beginMatch beginMatch]];
	}
	
	if (endRegexp == nil)
	{
		INFO(@"!!!!!!!!! no end regexp?");
		return nil;
	}
	
	// get all matches, one might be overlapped by a subpattern
	regexps_tried++;
	NSArray *matches = nil;
	matches = [endRegexp allMatchesInCharacters:chars range:aRange start:offset];

	regexps_matched += [matches count];

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
	NSMutableArray *matchingPatterns = [[NSMutableArray alloc] init];
	NSMutableDictionary *pattern;

	ViSyntaxMatch *topOpenMatch = [openMatches lastObject];
	if (topOpenMatch)
	{
		NSArray *endMatches = [self endMatchesForBeginMatch:topOpenMatch inRange:aRange];
		DEBUG(@"found %u possible end matches to scope [%@]", [endMatches count], [topOpenMatch scope]);
		ViRegexpMatch *match;
		for (match in endMatches)
		{
			ViSyntaxMatch *m = [[ViSyntaxMatch alloc] initWithMatch:match andPattern:[topOpenMatch pattern] atIndex:0];
			[m setEndMatch:match];
			[matchingPatterns addObject:m];
		}
	}

	int i = 0; // patterns in textmate bundles are ordered so we need to keep track of the index in the patterns array
	for (pattern in patterns)
	{
		/* Match all patterns against this range.
		 */
		ViRegexp *regexp = [pattern objectForKey:@"matchRegexp"];
		if (regexp == nil)
			regexp = [pattern objectForKey:@"beginRegexp"];
		if (regexp == nil)
			continue;
		NSArray *matches;
		regexps_tried++;
		matches = [regexp allMatchesInCharacters:chars range:aRange start:offset];

		regexps_matched += [matches count];

		if ([matches count] == 0)
			DEBUG(@"  matching against pattern %@", [pattern objectForKey:@"name"]);
		else
			DEBUG(@"  matching against pattern %@ = %i matches", [pattern objectForKey:@"name"], [matches count]);

		ViRegexpMatch *match;
		for (match in matches)
		{
			ViSyntaxMatch *viMatch = [[ViSyntaxMatch alloc] initWithMatch:match andPattern:pattern atIndex:i];
			[matchingPatterns addObject:viMatch];
		}

		++i;
	}
	[matchingPatterns sortUsingSelector:@selector(sortByLocation:)];

	DEBUG(@"applying %u matches in range %u + %u", [matchingPatterns count], aRange.location, aRange.length);
	NSUInteger lastLocation = aRange.location;
	ViSyntaxMatch *aMatch;
	for (aMatch in matchingPatterns)
	{
		if ([aMatch beginLocation] < lastLocation)
		{
			// skip overlapping matches
			regexps_overlapped++;
			DEBUG(@"skipping overlapping match for [%@] at %u + %u", [aMatch scope], [aMatch beginLocation], [aMatch beginLength]);
			continue;
		}

		if ([aMatch beginLocation] > lastLocation)
		{
			// Apply current scopes before adding the new match
			[self setScopes:topScopes inRange:NSMakeRange(lastLocation, [aMatch beginLocation] - lastLocation)];
		}

		if ([aMatch isSingleLineMatch])
		{
			DEBUG(@"got match on [%@] at %u + %u (subpattern)",
			      [aMatch scope],
			      [[aMatch beginMatch] rangeOfMatchedString].location,
			      [[aMatch beginMatch] rangeOfMatchedString].length);
			if ([aMatch scope])
			{
				/* We might not have a scope for the whole match. There is probably only captures, which is ok. */
				NSArray *newScopes = [topScopes arrayByAddingObject:[aMatch scope]];
				[self setScopes:newScopes inRange:[aMatch matchedRange]];
				[self highlightCapturesInMatch:aMatch topScopes:newScopes];
			}
			else
				[self highlightCapturesInMatch:aMatch topScopes:topScopes];
		}
		else if ([aMatch endMatch])
		{
			ViRegexpMatch *endMatch = [aMatch endMatch];
			[topOpenMatch setEndMatch:endMatch];
			DEBUG(@"got end match on [%@] at %u + %u",
			      [aMatch scope],
			      [endMatch rangeOfMatchedString].location,
			      [endMatch rangeOfMatchedString].length);

			topScopes = [self scopesFromMatches:openMatches withoutContentForMatch:topOpenMatch];
			[self setScopes:topScopes inRange:[endMatch rangeOfMatchedString]];
			[self highlightEndCapturesInMatch:aMatch topScopes:topScopes];

			// pop one or more open matches off the stack and return the rest
			while ([openMatches count] > 0)
			{
				openMatches = [openMatches subarrayWithRange:NSMakeRange(0, [openMatches count] - 1)];
				topOpenMatch = [openMatches lastObject];
				if (topOpenMatch == nil)
					break;
				NSArray *endMatches = [self endMatchesForBeginMatch:topOpenMatch inRange:[endMatch rangeOfMatchedString]];
				// if the next top open match also matches the end range,
				// and it is a look-ahead match, keep popping off open matches
				if (endMatches == nil || [[endMatches objectAtIndex:0] rangeOfMatchedString].length != 0)
					break;
			}
			
			DEBUG(@"returning %i continuation matches", [openMatches count]);
			return [openMatches count] > 0 ? openMatches : nil;
		}
		else
		{
			DEBUG(@"got begin match on [%@] at %u + %u", [aMatch scope], [aMatch beginLocation], [aMatch beginLength]);
			NSArray *newTopScopes = [aMatch scope] ? [topScopes arrayByAddingObject:[aMatch scope]] : topScopes;
			[self setScopes:newTopScopes inRange:[[aMatch beginMatch] rangeOfMatchedString]];
			// search for end match from after the begin match to EOL
			NSRange range = aRange;
			range.location = NSMaxRange([[aMatch beginMatch] rangeOfMatchedString]);
			range.length = NSMaxRange(aRange) - range.location;
			logIndent++;
			BOOL tmpEOL = NO;
			NSArray *continuationMatches = [self applyPatterns:[language expandedPatternsForPattern:[aMatch pattern]]
								   inRange:range
							       openMatches:[openMatches arrayByAddingObject:aMatch]
								reachedEOL:&tmpEOL];
			logIndent--;
			// need to highlight captures _after_ the main pattern has been highlighted
			[self highlightBeginCapturesInMatch:aMatch topScopes:newTopScopes];
			if (tmpEOL == YES)
			{
				if (reachedEOL)
					*reachedEOL = YES;
				DEBUG(@"returning %i continuation matches", [continuationMatches count]);
				return continuationMatches;
			}
		}
		lastLocation = [aMatch endLocation];
		// just stop if we passed our line range
		if (lastLocation >= NSMaxRange(aRange))
		{
			DEBUG(@"skipping further matches as we passed our line range");
			break;
		}
	}

	if (lastLocation < NSMaxRange(aRange))
		[self setScopes:topScopes inRange:NSMakeRange(lastLocation, NSMaxRange(aRange) - lastLocation)];

done:
	if (reachedEOL)
		*reachedEOL = YES;

	if (openMatches)
	{
		DEBUG(@"returning %i continuation matches", [openMatches count]);
		return openMatches;
	}
	return nil;
}

- (NSArray *)scopesFromMatches:(NSArray *)matches withoutContentForMatch:(ViSyntaxMatch *)skipContentMatch
{
	NSMutableArray *scopes = [[NSMutableArray alloc] initWithCapacity:[matches count] + 1];
	[scopes addObject:[language name]];
	ViSyntaxMatch *m;
	for (m in matches)
	{
		if ([m scope])
			[scopes addObject:[m scope]];
		if (m != skipContentMatch)
		{
			NSString *contentName = [[m pattern] objectForKey:@"contentName"];
			if (contentName)
			{
				[scopes addObject:contentName];
			}
		}
	}

	DEBUG(@"got scopes [%@]", [scopes componentsJoinedByString:@" "]);
	return scopes;
}

- (NSArray *)highlightLineInRange:(NSRange)aRange
              continueWithMatches:(NSArray *)continuedMatches
{
	DEBUG(@"-----> line range = %u (%u) + %u", aRange.location, aRange.location, aRange.length);
	NSUInteger lastLocation = aRange.location;

	// should we continue on multi-line matches?
	BOOL reachedEOL = NO;
	while ([continuedMatches count] > 0)
	{
		DEBUG(@"continuing with match [%@] (of %i total) at %@", [[continuedMatches lastObject] scope], [continuedMatches count], NSStringFromRange(aRange));

		ViSyntaxMatch *m;
		for (m in continuedMatches)
		{
			[m setBeginLocation:aRange.location];
		}

		ViSyntaxMatch *topMatch = [continuedMatches lastObject];

		continuedMatches = [self applyPatterns:[language expandedPatternsForPattern:[topMatch pattern]]
					       inRange:aRange
					   openMatches:continuedMatches
					    reachedEOL:&reachedEOL];

		if (reachedEOL)
			return continuedMatches;
		lastLocation = [topMatch endLocation];

		// adjust the line range
		if (lastLocation >= NSMaxRange(aRange))
			return nil;
		aRange.length = NSMaxRange(aRange) - lastLocation;
		aRange.location = lastLocation;
	}

	// search top-level patterns
	return [self applyPatterns:[language patterns]
	                   inRange:aRange
	               openMatches:[NSArray array]
	                reachedEOL:nil];
}

- (void)pushContinuations:(NSValue *)rangeValue
{
	NSRange range = [rangeValue rangeValue];
	unsigned lineno = range.location;
	int n = range.length;

	NSArray *prev;
	if (lineno == 0)
		prev = [NSArray array];
	else
		prev = [continuations objectAtIndex:(lineno - 1)];

	DEBUG(@"pushing %i continuations after line %i, copying scopes %@", n, lineno, prev);

	while (n--)
	{
		[continuations insertObject:[prev copy] atIndex:lineno];
	}
}

- (void)pullContinuations:(NSValue *)rangeValue
{
	NSRange range = [rangeValue rangeValue];
	unsigned lineno = range.location;
	int n = range.length;

	DEBUG(@"pulling %i continuations at line %i", n, lineno);

	while (n--)
	{
		[continuations removeObjectAtIndex:lineno];
	}
}

- (void)parseContext:(ViSyntaxContext *)aContext
{
#if 0
	struct timeval start;
	struct timeval stop_time;
	struct timeval diff;
	gettimeofday(&start, NULL);
#endif

	context = aContext;

	regexps_tried = 0;
	regexps_overlapped = 0;
	regexps_matched = 0;
	regexps_cached = 0;

	[[NSGarbageCollector defaultCollector] disable];

	offset = context.range.location;
	chars = context.characters;
	unsigned lineno = context.lineOffset;

	DEBUG(@"parsing line %u (%u -> %u) in thread %p, context %p",
		context.lineOffset,
		context.range.location,
		NSMaxRange(context.range),
		[NSThread currentThread],
		context);
	
	NSArray *continuedMatches = [self continuedMatchesForLine:lineno - 1];
	
	NSUInteger nextRange = offset;
	NSUInteger maxRange = NSMaxRange(context.range);

	// highlight each line separately
	for (;;)
	{
		NSUInteger end = nextRange;
		while (end < maxRange && chars[end - offset] != '\n') // FIXME: need updating for other line endings
			++end;
		if (end < maxRange)
			++end;
		if (end > maxRange)
			end = NSNotFound;

		if (end == nextRange || end == NSNotFound)
			break;
		NSRange line = NSMakeRange(nextRange, end - nextRange);

		DEBUG(@"---> line number %i (%u -> %u, w/offset %u, length %u)", lineno, nextRange, end, offset, end - nextRange);

		continuedMatches = [self highlightLineInRange:line continueWithMatches:continuedMatches];
		nextRange = end;

		NSArray *endMatches = [self continuedMatchesForLine:lineno];
		[self setContinuation:continuedMatches forLine:lineno];

		if (nextRange >= maxRange)
		{
			if (endMatches == nil || ![continuedMatches isEqualToPatternArray:endMatches])
			{
				DEBUG(@"detected changed line end matches in incremental mode at line %u", lineno);
				/* Signal that we must continue re-parsing lines following this line.
				 */
				context.lineOffset = lineno + 1;
			}
			break;
		}
		else if (context.restarting)
		{
			if (endMatches && [continuedMatches isEqualToPatternArray:endMatches])
			{
				DEBUG(@"detected matching line end matches, stopping at line %u", lineno);
				break;
			}
		}

		lineno++;
	}

#if 0
	gettimeofday(&stop_time, NULL);
	timersub(&stop_time, &start, &diff);
	unsigned ms = diff.tv_sec * 1000 + diff.tv_usec / 1000;
	INFO(@"regexps tried: %u, matched: %u, overlapped: %u, cached: %u  => %u lines in %.3f s",
		regexps_tried, regexps_matched, regexps_overlapped, regexps_cached, lineno + 1, (float)ms / 1000.0);
#endif

	[context setRange:NSMakeRange(offset, nextRange - offset)];
	[context setScopes:[scopeTree allObjects]];

	chars = NULL;
	[scopeTree removeAllObjects]; // FIXME: cheaper to just allocate a new tree?
	[uglyHack removeAllObjects];

	[[NSGarbageCollector defaultCollector] enable];
	[[NSGarbageCollector defaultCollector] collectIfNeeded];
}

@end

