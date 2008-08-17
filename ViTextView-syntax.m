#import "ViTextView.h"
#import "ViLanguageStore.h"

#define DEBUG(fmt, ...)
/*#define DEBUG(fmt, ...) do { \
	NSString *ws = [@"" stringByPaddingToLength:indent*2 withString:@" " startingAtIndex:0]; \
	NSLog([NSString stringWithFormat:@"%@%@", ws, fmt], ## __VA_ARGS__); \
} while(0)*/

@interface ViSyntaxMatch : NSObject
{
	OGRegularExpressionMatch *beginMatch;
	OGRegularExpressionMatch *endMatch;
	NSMutableDictionary *pattern;
	int patternIndex;
	NSUInteger beginLocation;
	NSUInteger beginLength;
}
- (id)initWithMatch:(OGRegularExpressionMatch *)aMatch andPattern:(NSMutableDictionary *)aPattern atIndex:(int)i;
- (NSComparisonResult)sortByLocation:(ViSyntaxMatch *)match;
- (OGRegularExpression *)endRegexp;
- (NSUInteger)beginLocation;
- (NSUInteger)beginLength;
- (void)setBeginLocation:(NSUInteger)aLocation;
- (NSUInteger)endLocation;
- (void)setEndMatch:(OGRegularExpressionMatch *)aMatch;
- (NSString *)scope;
- (NSRange)matchedRange;
- (NSRange)matchedRangeExclusive;
- (NSMutableDictionary *)pattern;
- (OGRegularExpressionMatch *)beginMatch;
- (OGRegularExpressionMatch *)endMatch;
- (int)patternIndex;
- (BOOL)isSingleLineMatch;
- (NSString *)description;
@end

@implementation ViSyntaxMatch
- (id)initWithMatch:(OGRegularExpressionMatch *)aMatch andPattern:(NSMutableDictionary *)aPattern atIndex:(int)i
{
	self = [super init];
	if(self)
	{
		beginMatch = aMatch;
		pattern = aPattern;
		patternIndex = i;
		if(aMatch)
		{
			beginLocation = [aMatch rangeOfMatchedString].location;
			beginLength = [aMatch rangeOfMatchedString].length;
		}
	}
	return self;
}
- (NSComparisonResult)sortByLocation:(ViSyntaxMatch *)anotherMatch
{
	if([self beginLocation] < [anotherMatch beginLocation])
		return NSOrderedAscending;
	if([self beginLocation] > [anotherMatch beginLocation])
		return NSOrderedDescending;
	if([self patternIndex] < [anotherMatch patternIndex])
		return NSOrderedAscending;
	if([self patternIndex] > [anotherMatch patternIndex])
		return NSOrderedDescending;
	return NSOrderedSame;
}
- (OGRegularExpression *)endRegexp
{
	return [pattern objectForKey:@"endRegexp"];
}
- (NSUInteger)beginLocation
{
	return beginLocation;
}
- (NSUInteger)beginLength
{
	return beginLength;
}
- (void)setBeginLocation:(NSUInteger)aLocation
{
	// used for continued multi-line matches
	beginLocation = aLocation;
	beginLength = 0;
}
- (NSUInteger)endLocation
{
	if(endMatch)
		return NSMaxRange([endMatch rangeOfMatchedString]);
	else
		return NSMaxRange([beginMatch rangeOfMatchedString]); // FIXME: ???
}
- (void)setEndMatch:(OGRegularExpressionMatch *)aMatch
{
	endMatch = aMatch;
}
- (NSString *)scope
{
	return [pattern objectForKey:@"name"];
}
- (NSRange)matchedRange
{
	NSRange range = NSMakeRange([self beginLocation], [self endLocation] - [self beginLocation]);
	if(range.length < 0)
	{
		NSLog(@"negative length, beginLocation = %u, endLocation = %u", [self beginLocation], [self endLocation]);
		range.length = 0;
	}
	return range;
}
- (NSRange)matchedRangeExclusive
{
	NSRange range;
	range.location = [self beginLocation] + [self beginLength];
	range.length = [[self endMatch] rangeOfMatchedString].location - range.location;
	return range;
}
- (NSMutableDictionary *)pattern;
{
	return pattern;
}
- (OGRegularExpressionMatch *)beginMatch
{
	return beginMatch;
}
- (OGRegularExpressionMatch *)endMatch
{
	return endMatch;
}
- (int)patternIndex
{
	return patternIndex;
}
- (BOOL)isSingleLineMatch
{
	return [pattern objectForKey:@"begin"] == nil;
}
- (NSString *)description
{
	return [NSString stringWithFormat:@"ViSyntaxMatch: scope = %@", [self scope]];
}
@end


@interface NSArray (patternArray)
- (BOOL)isEqualToPatternArray:(NSArray *)otherArray;
@end
@implementation NSArray (patternArray)
- (BOOL)isEqualToPatternArray:(NSArray *)otherArray
{
	int i, c = [self count];
	if(otherArray == self)
		return YES;
	if(c != [otherArray count])
		return NO;
	for(i = 0; i < c; i++)
	{
		if([[self objectAtIndex:i] pattern] != [[otherArray objectAtIndex:i] pattern])
			return NO;
	}
	return YES;
}
@end


@interface ViTextView (syntax_private)
- (ViSyntaxMatch *)highlightLineInRange:(NSRange)aRange continueWithMatch:(ViSyntaxMatch *)continuedMatch;
- (NSArray *)searchEndForMatch:(NSArray *)openMatches inRange:(NSRange)aRange topScopes:(NSArray *)topScopes reachedEOL:(BOOL *)reachedEOL;
@end

@implementation ViTextView (syntax)

- (void)applyScopes:(NSArray *)aScopeArray inRange:(NSRange)aRange
{
	if(aScopeArray == nil)
		return;

	NSUInteger l = aRange.location;
	while(l < NSMaxRange(aRange))
	{
		NSRange scopeRange;
		NSMutableArray *oldScopes = [[self layoutManager] temporaryAttribute:ViScopeAttributeName
								 atCharacterIndex:l
							    longestEffectiveRange:&scopeRange
									  inRange:NSMakeRange(l, NSMaxRange(aRange) - l)];
		NSMutableArray *scopes = [[NSMutableArray alloc] init];
		if(oldScopes)
		{
			[scopes addObjectsFromArray:oldScopes];
		}
		// append the new scope selector
		[scopes addObjectsFromArray:aScopeArray];

		// apply (merge) the scope selector in the maximum range
		if(scopeRange.location < l)
		{
			scopeRange.length -= l - scopeRange.location;
			scopeRange.location = l;
		}
		if(NSMaxRange(scopeRange) > NSMaxRange(aRange))
			scopeRange.length = NSMaxRange(aRange) - l;

		DEBUG(@"applying scopes [%@] to range %u + %u", [scopes componentsJoinedByString:@" "], scopeRange.location, scopeRange.length);		
		[[self layoutManager] addTemporaryAttribute:ViScopeAttributeName value:scopes forCharacterRange:scopeRange];

		// get the theme attributes for this collection of scopes
		NSDictionary *attributes = [theme attributesForScopes:scopes];
		[[self layoutManager] addTemporaryAttributes:attributes forCharacterRange:scopeRange];

		l = NSMaxRange(scopeRange);
	}
}

- (void)applyScope:(NSString *)aScope inRange:(NSRange)aRange
{
	[self applyScopes:[NSArray arrayWithObject:aScope] inRange:aRange];
}

- (void)highlightMatch:(ViSyntaxMatch *)aMatch inRange:(NSRange)aRange
{
	[self applyScope:[aMatch scope] inRange:aRange];
}

- (void)highlightMatch:(ViSyntaxMatch *)aMatch
{
	[self highlightMatch:aMatch inRange:[aMatch matchedRange]];
}

- (void)highlightCaptures:(NSString *)captureType inPattern:(NSDictionary *)pattern withMatch:(OGRegularExpressionMatch *)aMatch
{
	NSDictionary *captures = [pattern objectForKey:captureType];
	if(captures == nil)
		captures = [pattern objectForKey:@"captures"];
	if(captures == nil)
		return;

	NSString *key;
	for(key in [captures allKeys])
	{
		NSDictionary *capture = [captures objectForKey:key];
		NSRange r = [aMatch rangeOfSubstringAtIndex:[key intValue]];
		if(r.length > 0)
		{
			DEBUG(@"got capture [%@] at %u + %u", [capture objectForKey:@"name"], r.location, r.length);
			[self applyScope:[capture objectForKey:@"name"] inRange:r];
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

- (void)matchAllPatterns:(NSArray *)patterns inRange:(NSRange)aRange toArray:(NSMutableArray *)matchingPatterns
{
	NSMutableDictionary *pattern;
	int i = 0; // patterns in textmate bundles are ordered so we need to keep track of the index in the patterns array
	for(pattern in patterns)
	{
		/* Match all patterns against this line. We can probably do something smarter here,
		 * like limiting the range after a match.
		 */
		
		OGRegularExpression *regexp = [pattern objectForKey:@"matchRegexp"];
		if(regexp == nil)
			regexp = [pattern objectForKey:@"beginRegexp"];
		if(regexp == nil)
			continue;
		NSArray *matches = [regexp allMatchesInString:[storage string] range:aRange];
		OGRegularExpressionMatch *match;
		for(match in matches)
		{
			ViSyntaxMatch *viMatch = [[ViSyntaxMatch alloc] initWithMatch:match andPattern:pattern atIndex:i];
			[matchingPatterns addObject:viMatch];
		}
		++i;
	}
	[matchingPatterns sortUsingSelector:@selector(sortByLocation:)];
}

- (NSArray *)applyMatchingPatterns:(NSArray *)matchingPatterns
			   inRange:(NSRange)aRange
			 topScopes:(NSArray *)topScopes
		       openMatches:(NSArray *)openMatches
			reachedEOL:(BOOL *)reachedEOL
{
	if(reachedEOL)
		*reachedEOL = NO;

	DEBUG(@"applying %u matches in range %u + %u", [matchingPatterns count], aRange.location, aRange.length);
	NSUInteger lastLocation = aRange.location;
	ViSyntaxMatch *aMatch;
	for(aMatch in matchingPatterns)
	{
		if([aMatch beginLocation] < lastLocation)
		{
			// skip overlapping matches
			DEBUG(@"skipping overlapping match for [%@] at %u + %u", [aMatch scope], [aMatch beginLocation], [aMatch beginLength]);
			continue;
		}

		if([aMatch beginLocation] > lastLocation)
			[self applyScopes:topScopes inRange:NSMakeRange(lastLocation, [aMatch beginLocation] - lastLocation)];

		if([aMatch isSingleLineMatch])
		{
			DEBUG(@"got match on [%@] at %u + %u (subpattern)",
			      [aMatch scope],
			      [[aMatch beginMatch] rangeOfMatchedString].location,
			      [[aMatch beginMatch] rangeOfMatchedString].length);
			[self applyScopes:[topScopes arrayByAddingObject:[aMatch scope]] inRange:[aMatch matchedRange]];
			[self highlightCapturesInMatch:aMatch];
		}
		else if([aMatch endMatch])
		{
			ViSyntaxMatch *openMatch = [openMatches lastObject];
			[openMatch setEndMatch:[aMatch endMatch]];
			DEBUG(@"got end match on [%@] at %u + %u (subpattern)",
			      [aMatch scope],
			      [[aMatch endMatch] rangeOfMatchedString].location,
			      [[aMatch endMatch] rangeOfMatchedString].length);

			if([[aMatch endMatch] rangeOfMatchedString].length == 0)
			{
				DEBUG(@"    NOTE: got zero-width match for pattern [%@]", [[aMatch pattern] objectForKey:@"end"]);
			}
			[self applyScopes:topScopes inRange:[[aMatch endMatch] rangeOfMatchedString]];
			[self highlightEndCapturesInMatch:aMatch];

			// pop one open match off the stack and return the rest
			if([openMatches count] > 1)
			{
				DEBUG(@"returning %i continuation matches", [openMatches count] - 1);
				return [openMatches subarrayWithRange:NSMakeRange(0, [openMatches count] - 1)];
			}
			return nil;
		}
		else
		{
			DEBUG(@"got begin match on [%@] at %u + %u", [aMatch scope], [aMatch beginLocation], [aMatch beginLength]);
			NSArray *newTopScopes = [aMatch scope] ? [topScopes arrayByAddingObject:[aMatch scope]] : topScopes;
			[self applyScopes:newTopScopes inRange:[[aMatch beginMatch] rangeOfMatchedString]];
			// search for end match from after the begin match to EOL
			NSRange range = aRange;
			range.location = NSMaxRange([[aMatch beginMatch] rangeOfMatchedString]);
			range.length = NSMaxRange(aRange) - range.location;
			indent++;
			BOOL tmpEOL = NO;
			NSArray *continuationMatches = [self searchEndForMatch:[openMatches arrayByAddingObject:aMatch] inRange:range topScopes:newTopScopes reachedEOL:&tmpEOL];
			indent--;
			// need to highlight captures _after_ the main pattern has been highlighted
			[self highlightBeginCapturesInMatch:aMatch];
			if(tmpEOL)
			{
				if(reachedEOL)
					*reachedEOL = YES;
				DEBUG(@"returning %i continuation matches", [continuationMatches count]);
				return continuationMatches;
			}
		}
		lastLocation = [aMatch endLocation];
		// just stop if we passed our line range
		if(lastLocation >= NSMaxRange(aRange))
		{
			DEBUG(@"skipping further matches as we passed our line range");
			break;
		}
	}

	if(lastLocation < NSMaxRange(aRange))
		[self applyScopes:topScopes inRange:NSMakeRange(lastLocation, NSMaxRange(aRange) - lastLocation)];

	if(reachedEOL)
		*reachedEOL = YES;

	if(openMatches)
	{
		DEBUG(@"returning %i continuation matches", [openMatches count]);
		return openMatches;
	}
	return nil;
}

/* returns an array of continuation matches
 */
- (NSArray *)searchEndForMatch:(NSArray *)openMatches inRange:(NSRange)aRange topScopes:(NSArray *)topScopes reachedEOL:(BOOL *)reachedEOL
{
	ViSyntaxMatch *openMatch = [openMatches lastObject];

	DEBUG(@"searching for end match to [%@] in range %u + %u (%i open matches, topScopes = [%@])",
	      [openMatch scope], aRange.location, aRange.length, [openMatches count], [topScopes componentsJoinedByString:@" "]);

	OGRegularExpression *endRegexp = [openMatch endRegexp];
	if(endRegexp == nil)
	{
		DEBUG(@"************* => compiling pattern with back references for scope [%@]", [openMatch scope]);
		endRegexp = [language compileRegexp:[[openMatch pattern] objectForKey:@"end"]
			 withBackreferencesToRegexp:[openMatch beginMatch]];
	}

	if(endRegexp == nil)
	{
		DEBUG(@"!!!!!!!!! no end regexp?");
		return nil;
	}

	NSMutableArray *matchingPatterns = [[NSMutableArray alloc] init];

	// get all matches, one might be overlapped by a subpattern
	NSArray *matches = [endRegexp allMatchesInString:[storage string] range:aRange];

	NSArray *subPatterns = [language expandedPatternsForPattern:[openMatch pattern]];
	DEBUG(@"found %u possible end matches to scope [%@]", [matches count], [openMatch scope]);
	OGRegularExpressionMatch *match;
	for(match in matches)
	{
		ViSyntaxMatch *m = [[ViSyntaxMatch alloc] initWithMatch:match andPattern:[openMatch pattern] atIndex:0];
		[m setEndMatch:match];
		[matchingPatterns addObject:m];
	}
	
	[self matchAllPatterns:subPatterns inRange:aRange toArray:matchingPatterns];
	return [self applyMatchingPatterns:matchingPatterns inRange:aRange topScopes:topScopes openMatches:openMatches reachedEOL:reachedEOL];
}

- (NSArray *)highlightLineInRange:(NSRange)aRange continueWithMatches:(NSArray *)continuedMatches
{
	DEBUG(@"-----> line range = %u + %u", aRange.location, aRange.length);
	NSUInteger lastLocation = aRange.location;

	// should we continue on multi-line matches?
	BOOL reachedEOL = NO;
	while([continuedMatches count] > 0)
	{
		DEBUG(@"continuing with match [%@] (of %i total)", [[continuedMatches lastObject] scope], [continuedMatches count]);

		NSMutableArray *topScopes = [[NSMutableArray alloc] init];
		ViSyntaxMatch *m;
		for(m in continuedMatches)
		{
			[m setBeginLocation:aRange.location];
			if([m scope])
				[topScopes addObject:[m scope]];
		}

		ViSyntaxMatch *topMatch = [continuedMatches lastObject];

		continuedMatches = [self searchEndForMatch:continuedMatches inRange:aRange topScopes:topScopes reachedEOL:&reachedEOL];
		if(reachedEOL)
			return continuedMatches;
		lastLocation = [topMatch endLocation];

		// adjust the line range
		if(lastLocation >= NSMaxRange(aRange))
			return nil;
		aRange.length = NSMaxRange(aRange) - lastLocation;
		aRange.location = lastLocation;
	}


	// if we get here, we have no open matches

	// keep an array of matches so we can sort it in order to skip overlapping matches
	NSMutableArray *matchingPatterns = [[NSMutableArray alloc] init];

	// search top-level patterns
	[self matchAllPatterns:[language patterns] inRange:aRange toArray:matchingPatterns];
	return [self applyMatchingPatterns:matchingPatterns inRange:aRange topScopes:[NSArray array] openMatches:[NSArray array] reachedEOL:nil];
}

- (NSArray *)continuedMatchesForLocation:(NSUInteger)location
{
	NSArray *continuedMatches = [[self layoutManager] temporaryAttribute:ViContinuationAttributeName
							    atCharacterIndex:IMAX(0, location - 1)
							      effectiveRange:NULL];
	if(continuedMatches)
		DEBUG(@"detected %i previous scopes at location %u", [continuedMatches count], location);
	return continuedMatches;
}

- (void)resetAttributesInRange:(NSRange)aRange
{
	NSDictionary *defaultAttributes = nil;
	if(language)
	{
		defaultAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
					  [theme foregroundColor], NSForegroundColorAttributeName,
					  [NSArray arrayWithObject:[language name]], ViScopeAttributeName,
					  nil];
	}
	else
	{
		defaultAttributes = [NSDictionary dictionaryWithObject:[theme foregroundColor] forKey:NSForegroundColorAttributeName];
	}
	[[self layoutManager] setTemporaryAttributes:defaultAttributes forCharacterRange:aRange];
}

- (void)highlightInRange:(NSRange)aRange restarting:(BOOL)isRestarting
{
	//DEBUG(@"%s range = %u + %u", _cmd, aRange.location, aRange.length);

	// if we're restarting, detect the previous scope so we can continue on a multi-line pattern, if any
	NSArray *continuedMatches = nil;
	if(isRestarting && aRange.location > 0)
	{
		continuedMatches = [self continuedMatchesForLocation:aRange.location];
	}

	NSArray *lastContinuedMatches = nil;
	if(isRestarting)
	{
		lastContinuedMatches = [self continuedMatchesForLocation:NSMaxRange(aRange)];
	}

	// reset attributes in the affected range
	[self resetAttributesInRange:aRange];

	// highlight each line separately
	NSUInteger nextRange = aRange.location;
	while(nextRange < NSMaxRange(aRange))
	{
		NSUInteger end;
		[self getLineStart:NULL end:&end contentsEnd:NULL forLocation:nextRange];
		if(end == nextRange || end == NSNotFound)
			break;
		NSRange line = NSMakeRange(nextRange, end - nextRange);
		continuedMatches = [self highlightLineInRange:line continueWithMatches:continuedMatches];
		nextRange = end;

		if(continuedMatches)
		{
			/* Mark the EOL character with the continuation patterns */
			[[self layoutManager] addTemporaryAttribute:ViContinuationAttributeName value:continuedMatches forCharacterRange:NSMakeRange(end - 1, 1)];
		}

		if(isRestarting && nextRange >= NSMaxRange(aRange) && nextRange < [storage length] && ![continuedMatches isEqualToPatternArray:lastContinuedMatches])
		{
			DEBUG(@"continuation matches at location %u have changed, and this is an incremental update", end);
			[self resetAttributesInRange:NSMakeRange(nextRange, [storage length] - nextRange)];
			aRange.length = [storage length] - aRange.location;
		}
	}
}

- (void)highlightInWrappedRange:(NSValue *)wrappedRange
{
	[self highlightInRange:[wrappedRange rangeValue] restarting:YES];
}

/*
 * Update syntax colors.
 */
- (void)textStorageDidProcessEditing:(NSNotification *)notification
{
	if(language == nil)
		return;

	NSRange area = [storage editedRange];

	// extend our range along line boundaries.
	NSUInteger bol, eol;
	[[storage string] getLineStart:&bol end:&eol contentsEnd:NULL forRange:area];
	area.location = bol;
	area.length = eol - bol;

	if(area.length == 0)
		return;

	// temporary attributes don't work right when called from a notification
	[self performSelector:@selector(highlightInWrappedRange:) withObject:[NSValue valueWithRange:area] afterDelay:0];
}

- (void)highlightEverything
{
	if(language == nil)
	{
		[self resetAttributesInRange:NSMakeRange(0, [[storage string] length])];
		return;
	}
	DEBUG(@"%s begin highlighting", _cmd);
	[storage beginEditing];
	[self highlightInRange:NSMakeRange(0, [[storage string] length]) restarting:NO];
	[storage endEditing];
	DEBUG(@"%s end highlighting", _cmd);
}

@end
