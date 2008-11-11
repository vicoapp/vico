#import "ViTextView.h"
#import "ViLanguageStore.h"
#import "ViSyntaxMatch.h"
#import "ViScope.h"
#import "MHSysTree.h"
#import "logging.h"

#include <sys/time.h>

@interface NSArray (patternArray)
- (BOOL)isEqualToPatternArray:(NSArray *)otherArray;
@end
@implementation NSArray (patternArray)
- (BOOL)isEqualToPatternArray:(NSArray *)otherArray
{
	int i, c = [self count];
	if (otherArray == self)
		return YES;
	if (c != [otherArray count])
		return NO;
	for (i = 0; i < c; i++)
	{
		if ([[self objectAtIndex:i] pattern] != [[otherArray objectAtIndex:i] pattern])
			return NO;
	}
	return YES;
}
@end




@interface ViTextView (syntax_private)
- (NSArray *)scopesFromMatches:(NSArray *)matches;
- (NSArray *)scopesFromMatches:(NSArray *)matches withoutContentForMatch:(ViSyntaxMatch *)skipContentMatch;
- (void)resetAttributesInRange:(NSRange)aRange;
- (void)startHighlightingInBackground:(NSArray *)continuedMatches range:(NSRange)range isRestarting:(BOOL)isRestarting;
@end

@implementation ViTextView (syntax)

- (void)addContinuation:(NSArray *)vars
{
	NSArray *continuedMatches = [vars objectAtIndex:0];
	NSRange range = [[vars objectAtIndex:1] rangeValue];
	[[self layoutManager] addTemporaryAttribute:ViContinuationAttributeName value:continuedMatches forCharacterRange:range];
}

- (void)applyScopes:(ViScope *)aScope
{
	DEBUG(@"applying scopes [%@] to range %u + %u", [aScope.scopes componentsJoinedByString:@" "], aScope.range.location, aScope.range.length);		
	[[self layoutManager] addTemporaryAttribute:ViScopeAttributeName value:aScope.scopes forCharacterRange:aScope.range];

	// get the theme attributes for this collection of scopes
	NSDictionary *attributes = [theme attributesForScopes:aScope.scopes];
	[[self layoutManager] addTemporaryAttributes:attributes forCharacterRange:aScope.range];
}

- (void)debugScopes:(ViScope *)aScope
{
	INFO(@"[%@] (%p) range %u + %u", [aScope.scopes componentsJoinedByString:@" "], aScope.scopes, aScope.range.location, aScope.range.length);
}

- (void)applyContext:(NSMutableArray *)context
{
#ifndef NO_DEBUG
	struct timeval start;
	struct timeval stop;
	struct timeval diff;
	gettimeofday(&start, NULL);
#endif

	// [[NSGarbageCollector defaultCollector] disable];

	NSRange wholeRange = [[context objectAtIndex:0] rangeValue];

	DEBUG(@"resetting attributes in range %@", NSStringFromRange(wholeRange));
	[self resetAttributesInRange:wholeRange];

	MHSysTree *beginTree = [context objectAtIndex:1];
	// [beginTree performSelectorWithAllObjects:@selector(debugScopes:) target:self];
	[beginTree performSelectorWithAllObjects:@selector(applyScopes:) target:self];

#ifndef NO_DEBUG
	gettimeofday(&stop, NULL);
	timersub(&stop, &start, &diff);
	unsigned ms = diff.tv_sec * 1000 + diff.tv_usec / 1000;
	INFO(@"applied %u scopes from context in range %@ => %.3f s",
		[beginTree count], NSStringFromRange(wholeRange), (float)ms / 1000.0);
#endif

	// [[NSGarbageCollector defaultCollector] enable];
}

- (void)applyScopes:(NSArray *)aScopeArray inRange:(NSRange)aRange context:(NSMutableArray *)context
{
	int c = [aScopeArray count];
	if (c == 0 || aRange.length == 0)
		return;

	MHSysTree *beginTree = [context objectAtIndex:1];

	struct rb_entry *e = [beginTree root];
	while (e)
	{
		ViScope *beginScope = e->obj;
		if (aRange.location < beginScope.range.location)
		{
			break;
			// FIXME: need to break partially matching scopes here!
			// e = [beginTree left:e];
		}
		else if (aRange.location > beginScope.range.location)
		{
			if (NSMaxRange(beginScope.range) == aRange.location)
			{
				NSString *scopeString = [aScopeArray componentsJoinedByString:@" "];
				if ([beginScope.scopes count] == c && [[beginScope.scopes componentsJoinedByString:@" "] isEqualToString:scopeString])
				{
					NSRange r = beginScope.range;
					r.length += aRange.length;
					beginScope.range = r;
					return;
				}
			}

			e = [beginTree right:e];
		}
		else
		{
			if (aRange.length > beginScope.range.length)
				e = [beginTree left:e];
			else if (aRange.length < beginScope.range.length)
				e = [beginTree right:e];
			else
			{
				beginScope.scopes = aScopeArray;
				return;
			}
		}
	}

	ViScope *scope = [[ViScope alloc] initWithScopes:aScopeArray range:aRange];
	[beginTree addObject:scope];
	[context addObject:scope]; // XXX: otherwise garbage collection fucks this up!
}

- (void)applyScope:(NSString *)aScope inRange:(NSRange)aRange context:(NSMutableArray *)context
{
	[self applyScopes:[NSArray arrayWithObject:aScope] inRange:aRange context:context];
}

- (void)highlightCaptures:(NSString *)captureType
                inPattern:(NSDictionary *)pattern
                withMatch:(ViRegexpMatch *)aMatch
                topScopes:(NSArray *)topScopes
                  context:(NSMutableArray *)context
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
			[self applyScopes:[topScopes arrayByAddingObject:[capture objectForKey:@"name"]] inRange:r context:context];
		}
	}
}

- (void)highlightBeginCapturesInMatch:(ViSyntaxMatch *)aMatch context:(NSMutableArray *)context topScopes:(NSArray *)topScopes
{
	[self highlightCaptures:@"beginCaptures" inPattern:[aMatch pattern] withMatch:[aMatch beginMatch] topScopes:topScopes context:context];
}

- (void)highlightEndCapturesInMatch:(ViSyntaxMatch *)aMatch context:(NSMutableArray *)context topScopes:(NSArray *)topScopes
{
	[self highlightCaptures:@"endCaptures" inPattern:[aMatch pattern] withMatch:[aMatch endMatch] topScopes:topScopes context:context];
}

- (void)highlightCapturesInMatch:(ViSyntaxMatch *)aMatch context:(NSMutableArray *)context topScopes:(NSArray *)topScopes
{
	[self highlightCaptures:@"captures" inPattern:[aMatch pattern] withMatch:[aMatch beginMatch] topScopes:topScopes context:context];
}

- (NSArray *)endMatchesForBeginMatch:(ViSyntaxMatch *)beginMatch inRange:(NSRange)aRange characters:(const unichar *)chars
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
	if (chars)
		matches = [endRegexp allMatchesInCharacters:chars range:aRange start:0];
	else
		matches = [endRegexp allMatchesInString:[storage string] range:aRange start:0];

	regexps_matched += [matches count];

	return matches;
}

- (NSArray *)applyPatterns:(NSArray *)patterns
		   inRange:(NSRange)aRange
	       openMatches:(NSArray *)openMatches
		reachedEOL:(BOOL *)reachedEOL
		matchCache:(NSMutableDictionary *)matchCache
		characters:(const unichar *)chars
	           context:(NSMutableArray *)context
{
	if (reachedEOL)
		*reachedEOL = NO;

	if (aRange.length == 0)
	{
		DEBUG(@"=============== detected zero-length range %u + %u", aRange.location, aRange.length);
		goto done;
	}

	DEBUG(@"searching %i patterns in range %u + %u", [patterns count], aRange.location, aRange.length);

	NSArray *topScopes = [self scopesFromMatches:openMatches];
	
	// keep an array of matches so we can sort it in order to skip overlapping matches
	NSMutableArray *matchingPatterns = [[NSMutableArray alloc] init];
	NSMutableDictionary *pattern;

	ViSyntaxMatch *topOpenMatch = [openMatches lastObject];
	if (topOpenMatch)
	{
		NSArray *endMatches = [self endMatchesForBeginMatch:topOpenMatch inRange:aRange characters:chars];
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
		matches = [matchCache objectForKey:[NSValue valueWithPointer:pattern]];
		if (matches == nil)
		{
			regexps_tried++;
			if (chars)
				matches = [regexp allMatchesInCharacters:chars range:aRange start:0];
			else
				matches = [regexp allMatchesInString:[storage string] range:aRange start:0];

			regexps_matched += [matches count];
			// INFO(@"caching %i matches for pattern [%@]", [matches count], regexp);
			[matchCache setObject:matches ?: [NSArray array] forKey:[NSValue valueWithPointer:pattern]];

			if ([matches count] == 0)
				DEBUG(@"  matching against pattern %@", [pattern objectForKey:@"name"]);
			else
				DEBUG(@"  matching against pattern %@ = %i matches", [pattern objectForKey:@"name"], [matches count]);
		}
		else
			regexps_cached += [matches count];

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
			[self applyScopes:topScopes inRange:NSMakeRange(lastLocation, [aMatch beginLocation] - lastLocation) context:context];
		}

		if ([aMatch isSingleLineMatch])
		{
			DEBUG(@"got match on [%@] at %u + %u (subpattern)",
			      [aMatch scope],
			      [[aMatch beginMatch] rangeOfMatchedString].location,
			      [[aMatch beginMatch] rangeOfMatchedString].length);
			NSMutableArray *newScopes = [[NSMutableArray alloc] init];
			[newScopes addObjectsFromArray:topScopes];
			if ([aMatch scope])
			{
				/* We might not have a scope for the whole match. There is probably only captures, which is ok. */
				[newScopes addObject:[aMatch scope]];
				[self applyScopes:newScopes inRange:[aMatch matchedRange] context:context];
			}
			[self highlightCapturesInMatch:aMatch context:context topScopes:newScopes];
		}
		else if ([aMatch endMatch])
		{
			[topOpenMatch setEndMatch:[aMatch endMatch]];
			DEBUG(@"got end match on [%@] at %u + %u",
			      [aMatch scope],
			      [[aMatch endMatch] rangeOfMatchedString].location,
			      [[aMatch endMatch] rangeOfMatchedString].length);

			topScopes = [self scopesFromMatches:openMatches withoutContentForMatch:topOpenMatch];
			[self applyScopes:topScopes inRange:[[aMatch endMatch] rangeOfMatchedString] context:context];
			[self highlightEndCapturesInMatch:aMatch context:context topScopes:topScopes];
			// [self performSelectorOnMainThread:@selector(highlightEndCapturesInMatch:) withObject:aMatch waitUntilDone:NO];

			// pop one or more open matches off the stack and return the rest
			while ([openMatches count] > 0)
			{
				openMatches = [openMatches subarrayWithRange:NSMakeRange(0, [openMatches count] - 1)];
				topOpenMatch = [openMatches lastObject];
				if (topOpenMatch == nil)
					break;
				NSArray *endMatches = [self endMatchesForBeginMatch:topOpenMatch inRange:[[aMatch endMatch] rangeOfMatchedString] characters:chars];
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
			[self applyScopes:newTopScopes inRange:[[aMatch beginMatch] rangeOfMatchedString] context:context];
			// search for end match from after the begin match to EOL
			NSRange range = aRange;
			range.location = NSMaxRange([[aMatch beginMatch] rangeOfMatchedString]);
			range.length = NSMaxRange(aRange) - range.location;
			logIndent++;
			BOOL tmpEOL = NO;
			NSArray *continuationMatches = [self applyPatterns:[language expandedPatternsForPattern:[aMatch pattern]]
								   inRange:range
							       openMatches:[openMatches arrayByAddingObject:aMatch]
								reachedEOL:&tmpEOL
								matchCache:matchCache
								characters:chars
							           context:context];
			logIndent--;
			// need to highlight captures _after_ the main pattern has been highlighted
			[self highlightBeginCapturesInMatch:aMatch context:context topScopes:newTopScopes];
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
		[self applyScopes:topScopes inRange:NSMakeRange(lastLocation, NSMaxRange(aRange) - lastLocation) context:context];

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
	NSMutableArray *scopes = [[NSMutableArray alloc] init];
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

- (NSArray *)scopesFromMatches:(NSArray *)matches
{
	return [self scopesFromMatches:matches withoutContentForMatch:nil];
}

- (NSArray *)highlightLineInRange:(NSRange)aRange
              continueWithMatches:(NSArray *)continuedMatches
                       characters:(const unichar *)chars
                          context:(NSMutableArray *)context
{
	DEBUG(@"-----> line range = %u (%u) + %u", aRange.location, aRange.location, aRange.length);
	NSUInteger lastLocation = aRange.location;

	NSMutableDictionary *matchCache = [[NSMutableDictionary alloc] init];

	// should we continue on multi-line matches?
	BOOL reachedEOL = NO;
	while ([continuedMatches count] > 0)
	{
		DEBUG(@"continuing with match [%@] (of %i total)", [[continuedMatches lastObject] scope], [continuedMatches count]);

		ViSyntaxMatch *m;
		for (m in continuedMatches)
		{
			[m setBeginLocation:aRange.location];
		}

		ViSyntaxMatch *topMatch = [continuedMatches lastObject];

		continuedMatches = [self applyPatterns:[language expandedPatternsForPattern:[topMatch pattern]]
					       inRange:aRange
					   openMatches:continuedMatches
					    reachedEOL:&reachedEOL
					    matchCache:matchCache
					    characters:chars
					       context:context];

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
	                reachedEOL:nil
	                 matchCache:matchCache
	                 characters:chars
	                    context:context];
}

- (NSArray *)continuedMatchesForLocation:(NSUInteger)location
{
	NSArray *continuedMatches = [[self layoutManager] temporaryAttribute:ViContinuationAttributeName
							    atCharacterIndex:IMAX(0, location - 1)
							      effectiveRange:NULL];
	if (continuedMatches)
		DEBUG(@"detected %i previous scopes at location %u", [continuedMatches count], location);
	return continuedMatches;
}

- (void)resetAttributesInRange:(NSRange)aRange
{
	if (aRange.length == 0)
		return;

	// [[self layoutManager] removeTemporaryAttribute:ViContinuationAttributeName forCharacterRange:aRange];
	// [[self layoutManager] removeTemporaryAttribute:NSFontAttributeName forCharacterRange:aRange];
	[[self layoutManager] removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:aRange];
	[[self layoutManager] removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:aRange];
	
	NSDictionary *defaultAttributes = nil;
	if (language)
	{
		[[self layoutManager] removeTemporaryAttribute:ViScopeAttributeName forCharacterRange:aRange];
		[[self layoutManager] removeTemporaryAttribute:NSUnderlineStyleAttributeName forCharacterRange:aRange];
		[[self layoutManager] removeTemporaryAttribute:NSObliquenessAttributeName forCharacterRange:aRange];

		defaultAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
					  [theme foregroundColor], NSForegroundColorAttributeName,
					    [self font], NSFontAttributeName,
					  nil];
	}

	[[self layoutManager] addTemporaryAttributes:defaultAttributes forCharacterRange:aRange];

	if (resetFont)
	{
		[self setFont:[self font]];
		resetFont = NO;
	}
}

- (void)highlightRange:(NSRange)aRange
   continueWithMatches:(NSArray *)continuedMatches
        verifyEndMatch:(NSArray *)endMatches         // nil on highlightThread
         continuations:(NSArray *)continuations      // nil on main thread
            characters:(unichar *)chars              // nil on main thread
{
	struct timeval start;
	struct timeval stop_time;
	struct timeval diff;
	gettimeofday(&start, NULL);

	regexps_tried = 0;
	regexps_overlapped = 0;
	regexps_matched = 0;
	regexps_cached = 0;

	NSUInteger lineno = 0;

	[[NSGarbageCollector defaultCollector] disable];

	NSMutableArray *context = [[NSMutableArray alloc] init];
	[context addObject:[NSValue valueWithRange:aRange]];
	[context addObject:[[MHSysTree alloc] initWithCompareSelector:@selector(compareBegin:)]];

	DEBUG(@"highlighting range %@", NSStringFromRange(aRange));
	
	// highlight each line separately
	NSUInteger lastScopeUpdate = aRange.location;
	NSUInteger nextRange = aRange.location;
	while (nextRange < NSMaxRange(aRange) && ![[NSThread currentThread] isCancelled])
	{
		NSUInteger end = nextRange;
		if (chars)
		{
			while (end < NSMaxRange(aRange) && chars[end] != '\n')
				++end;
			if (end < NSMaxRange(aRange))
				++end;
			if (end > NSMaxRange(aRange))
				end = NSNotFound;
		}
		else
		{
			[self getLineStart:NULL end:&end contentsEnd:NULL forLocation:nextRange];
		}
		if (end == nextRange || end == NSNotFound)
			break;
		NSRange line = NSMakeRange(nextRange, end - nextRange);

		DEBUG(@"---> line number %i", lineno);

		continuedMatches = [self highlightLineInRange:line continueWithMatches:continuedMatches characters:chars context:context];
		nextRange = end;

		if (continuedMatches)
		{
			/* Mark the EOL character with the continuation patterns */
			[self performSelectorOnMainThread:@selector(addContinuation:)
			                       withObject:[NSArray arrayWithObjects:continuedMatches,
			                                  [NSValue valueWithRange:NSMakeRange(end - 1, 1)],
			                                  nil]
			                    waitUntilDone:NO];
		}

		if (endMatches && nextRange >= NSMaxRange(aRange))
		{
			DEBUG(@"verifying end match in line %u: should be %@, is %@", lineno + 1, endMatches, continuedMatches);
			if (![continuedMatches isEqualToPatternArray:endMatches])
			{
				// XXX: we know we're in the main thread 'cause otherwise we don't have the end match
				DEBUG(@"detected changed line end matches in incremental mode");
				[self startHighlightingInBackground:continuedMatches range:NSMakeRange(nextRange, [storage length] - nextRange) isRestarting:YES];
			}
		}

		if (continuations && lineno < [continuations count] && [continuedMatches isEqualToPatternArray:[continuations objectAtIndex:lineno]])
		{
			DEBUG(@"detected matching line end matches in thread mode, stopping at lineno %u", lineno);
			break;
		}

		lineno++;
		if (lineno % 100 == 0)
		{
			MHSysTree *tree = [context objectAtIndex:1];
			[context replaceObjectAtIndex:1 withObject:[[MHSysTree alloc] initWithCompareSelector:@selector(compareBegin:)]];

			NSArray *contextCopy = [NSArray arrayWithObjects:
				[NSValue valueWithRange:NSMakeRange(lastScopeUpdate, nextRange - lastScopeUpdate)],
				tree,
				nil];
			[self performSelectorOnMainThread:@selector(applyContext:) withObject:contextCopy waitUntilDone:NO];
			lastScopeUpdate = nextRange;
		}
	}

	free(chars);

	gettimeofday(&stop_time, NULL);
	timersub(&stop_time, &start, &diff);
	unsigned ms = diff.tv_sec * 1000 + diff.tv_usec / 1000;
	INFO(@"regexps tried: %u, matched: %u, overlapped: %u, cached: %u  => %u lines in %.3f s",
		regexps_tried, regexps_matched, regexps_overlapped, regexps_cached, lineno + 1, (float)ms / 1000.0);

	if (![[NSThread currentThread] isCancelled])
	{
		[context replaceObjectAtIndex:0 withObject:[NSValue valueWithRange:NSMakeRange(lastScopeUpdate, nextRange - lastScopeUpdate)]];
		[self performSelectorOnMainThread:@selector(applyContext:) withObject:context waitUntilDone:NO];
	}

	[[NSGarbageCollector defaultCollector] enable];
	[[NSGarbageCollector defaultCollector] collectIfNeeded];
}

- (void)highlightInBackground:(NSArray *)vars
{
	NSRange range = [[vars objectAtIndex:0] rangeValue];
	unichar *chars = [[vars objectAtIndex:1] pointerValue];
	NSArray *continuedMatches = nil;
	NSArray *continuations = nil;
	if ([vars count] > 2)
		continuedMatches = [vars objectAtIndex:2];
	if ([vars count] > 3)
		continuations = [vars objectAtIndex:3];

	DEBUG(@"highlighting in background thread %p", [NSThread currentThread]);
	[self highlightRange:range continueWithMatches:continuedMatches verifyEndMatch:nil continuations:continuations characters:chars];
	if ([[NSThread currentThread] isCancelled])
	{
		DEBUG(@"highlight thread %p (%p) got cancelled", [NSThread currentThread], highlightThread);
	}
	else
	{
		DEBUG(@"highlight thread %p (%p) finished", [NSThread currentThread], highlightThread);
		highlightThread = nil; // XXX: race condition?
	}
}

- (void)startHighlightingInBackground:(NSArray *)continuedMatches range:(NSRange)range isRestarting:(BOOL)isRestarting
{
	DEBUG(@"allocating %u bytes", [storage length] * sizeof(unichar));
	unichar *chars = malloc([storage length] * sizeof(unichar));
	[[storage string] getCharacters:chars];

	if ([highlightThread isExecuting])
	{
		DEBUG(@"cancelling highlighting thread %p", highlightThread);
		[highlightThread cancel];
		highlightThread = nil;
		[[NSRunLoop mainRunLoop] cancelPerformSelectorsWithTarget:self];
	}

	NSMutableArray *continuations = nil;
	if (isRestarting)
	{
		continuations = [[NSMutableArray alloc] init];

		NSUInteger end = range.location;
		while (end < NSMaxRange(range))
		{
			NSUInteger nextEnd;
			[self getLineStart:NULL end:&nextEnd contentsEnd:NULL forLocation:end];
			
			NSArray *cont = [self continuedMatchesForLocation:nextEnd];
			if (cont == nil)
				break;
			[continuations addObject:cont];
			end = nextEnd;
		}
		DEBUG(@"collected %u continuations", [continuations count]);
	}

	highlightThread = [[NSThread alloc] initWithTarget:self selector:@selector(highlightInBackground:)
		object:[NSArray arrayWithObjects:[NSValue valueWithRange:range], [NSValue valueWithPointer:chars], continuedMatches, continuations, nil]];
	DEBUG(@"dispatching highlighting thread %p", highlightThread);
	[highlightThread start];
}

- (void)highlightRange:(NSRange)aRange isRestarting:(BOOL)isRestarting inBackground:(BOOL)inBackground
{
	// if we're restarting, detect the previous scope so we can continue on a multi-line pattern, if any
	NSArray *continuedMatches = nil;
	if (aRange.location > 0)
	{
		continuedMatches = [self continuedMatchesForLocation:aRange.location];
	}

	NSArray *endMatches = nil;
	if (isRestarting && continuedMatches)
	{
		endMatches = [self continuedMatchesForLocation:NSMaxRange(aRange)];
	}

	if (language)
	{

		if (inBackground)
		{
			[self startHighlightingInBackground:continuedMatches range:aRange isRestarting:isRestarting];
		}
		else
		{
			[self highlightRange:aRange
			 continueWithMatches:continuedMatches
			      verifyEndMatch:endMatches
			       continuations:nil
			          characters:NULL];
		}
	}
}

- (void)highlightInWrappedRange:(NSValue *)wrappedRange
{
	[self highlightRange:[wrappedRange rangeValue] isRestarting:YES inBackground:NO];
}

/*
 * Update syntax colors.
 */
- (void)textStorageDidProcessEditing:(NSNotification *)notification
{
	NSRange area = [storage editedRange];
	
	if ([storage length] == 0)
		resetFont = YES;
	
	if (ignoreEditing)
	{
		ignoreEditing = NO;
		return;
	}
	
	if (language == nil)
	{
		[self resetAttributesInRange:area];
		return;
	}
	
	/* If we're pasting whole lines that changes the continuation, we must include that
	 * last line ending to detect the change.
	 */
	if (area.length > 1 && [[storage string] characterAtIndex:NSMaxRange(area) - 1] == '\n')
		area.length = IMIN(area.length + 1, [storage length] - area.location);
	
	// extend our range along line boundaries.
	NSUInteger bol, eol;
	[[storage string] getLineStart:&bol end:&eol contentsEnd:NULL forRange:area];
	area.location = bol;
	area.length = eol - bol;

	if (area.length == 0)
		return;

	if ([highlightThread isExecuting])
	{
		DEBUG(@"cancelling highlighting thread %p", highlightThread);
		[highlightThread cancel];
		highlightThread = nil;
		[[NSRunLoop mainRunLoop] cancelPerformSelectorsWithTarget:self];
	}

	// temporary attributes don't work right when called from a notification
	// FIXME: try call this in - (void)layoutManagerDidInvalidateLayout:(NSLayoutManager *)sender instead
	[self performSelector:@selector(highlightInWrappedRange:) withObject:[NSValue valueWithRange:area] afterDelay:0.0];
}

- (void)highlightEverything
{
	if (language == nil)
	{
		[self resetAttributesInRange:NSMakeRange(0, [storage length])];
		return;
	}
	[storage beginEditing];
	[self highlightRange:NSMakeRange(0, [storage length]) isRestarting:NO inBackground:YES];
	[storage endEditing];
}

@end
