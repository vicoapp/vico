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
- (NSUInteger)endLocation;
- (NSString *)scope;
- (NSRange)matchedRange;
- (BOOL)isSingleLineMatch;
- (NSString *)description;

@property(readonly) int patternIndex;
@property(readonly) NSMutableDictionary *pattern;
@property(readonly) NSUInteger beginLocation;
@property(readonly) NSUInteger beginLength;
@property(readonly) OGRegularExpressionMatch *beginMatch;
@property(readonly) OGRegularExpressionMatch *endMatch;
@end

@implementation ViSyntaxMatch

@synthesize patternIndex;
@synthesize pattern;
@synthesize beginLocation;
@synthesize beginLength;
@synthesize beginMatch;
@synthesize endMatch;

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
- (void)setEndMatch:(OGRegularExpressionMatch *)aMatch
{
	endMatch = aMatch;
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

- (NSArray *)endMatchesForBeginMatch:(ViSyntaxMatch *)beginMatch inRange:(NSRange)aRange
{
	DEBUG(@"searching for end match to [%@] in range %u + %u",
	      [beginMatch scope], aRange.location, aRange.length);
	
	OGRegularExpression *endRegexp = [beginMatch endRegexp];
	if(endRegexp == nil)
	{
		DEBUG(@"************* => compiling pattern with back references for scope [%@]", [beginMatch scope]);
		endRegexp = [language compileRegexp:[[beginMatch pattern] objectForKey:@"end"]
			 withBackreferencesToRegexp:[beginMatch beginMatch]];
	}
	
	if(endRegexp == nil)
	{
		DEBUG(@"!!!!!!!!! no end regexp?");
		return nil;
	}
	
	// get all matches, one might be overlapped by a subpattern
	regexps_tried++;
	NSArray *matches = [endRegexp allMatchesInString:[storage string] range:aRange];
	regexps_matched += [matches count];
	
	return matches;
}

- (NSArray *)applyPatterns:(NSArray *)patterns
			   inRange:(NSRange)aRange
			 topScopes:(NSArray *)topScopes
		       openMatches:(NSArray *)openMatches
			reachedEOL:(BOOL *)reachedEOL
{
	if(reachedEOL)
		*reachedEOL = NO;
	
	// keep an array of matches so we can sort it in order to skip overlapping matches
	NSMutableArray *matchingPatterns = [[NSMutableArray alloc] init];
	NSMutableDictionary *pattern;

	ViSyntaxMatch *topOpenMatch = [openMatches lastObject];
	if(topOpenMatch)
	{
		NSArray *endMatches = [self endMatchesForBeginMatch:topOpenMatch inRange:aRange];
		DEBUG(@"found %u possible end matches to scope [%@]", [endMatches count], [topOpenMatch scope]);
		OGRegularExpressionMatch *match;
		for(match in endMatches)
		{
			ViSyntaxMatch *m = [[ViSyntaxMatch alloc] initWithMatch:match andPattern:[topOpenMatch pattern] atIndex:0];
			[m setEndMatch:match];
			[matchingPatterns addObject:m];
		}
	}

	int i = 0; // patterns in textmate bundles are ordered so we need to keep track of the index in the patterns array
	for(pattern in patterns)
	{
		/* Match all patterns against this range.
		 */

		OGRegularExpression *regexp = [pattern objectForKey:@"matchRegexp"];
		if(regexp == nil)
			regexp = [pattern objectForKey:@"beginRegexp"];
		if(regexp == nil)
			continue;
		regexps_tried++;
		NSArray *matches = [regexp allMatchesInString:[storage string] range:aRange];
		regexps_matched += [matches count];
		OGRegularExpressionMatch *match;
		for(match in matches)
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
	for(aMatch in matchingPatterns)
	{
		if([aMatch beginLocation] < lastLocation)
		{
			// skip overlapping matches
			regexps_overlapped++;
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
			if([aMatch scope])
			{
				/* We might not have a scope for the whole match. There is probably only captures, which is ok. */
				[self applyScopes:[topScopes arrayByAddingObject:[aMatch scope]] inRange:[aMatch matchedRange]];
			}
			[self highlightCapturesInMatch:aMatch];
		}
		else if([aMatch endMatch])
		{
			ViSyntaxMatch *openMatch = [openMatches lastObject];
			[openMatch setEndMatch:[aMatch endMatch]];
			DEBUG(@"got end match on [%@] at %u + %u",
			      [aMatch scope],
			      [[aMatch endMatch] rangeOfMatchedString].location,
			      [[aMatch endMatch] rangeOfMatchedString].length);

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
			NSArray *continuationMatches = [self applyPatterns:[language expandedPatternsForPattern:[aMatch pattern]]
								   inRange:range
								 topScopes:newTopScopes
							       openMatches:[openMatches arrayByAddingObject:aMatch]
								reachedEOL:&tmpEOL];
			indent--;
			// need to highlight captures _after_ the main pattern has been highlighted
			[self highlightBeginCapturesInMatch:aMatch];
			if(tmpEOL == YES)
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

		continuedMatches = [self applyPatterns:[language expandedPatternsForPattern:[topMatch pattern]]
					       inRange:aRange
					     topScopes:topScopes
					   openMatches:continuedMatches
					    reachedEOL:&reachedEOL];

		if(reachedEOL)
			return continuedMatches;
		lastLocation = [topMatch endLocation];

		// adjust the line range
		if(lastLocation >= NSMaxRange(aRange))
			return nil;
		aRange.length = NSMaxRange(aRange) - lastLocation;
		aRange.location = lastLocation;
	}

	// search top-level patterns
	return [self applyPatterns:[language patterns] inRange:aRange topScopes:[NSArray array] openMatches:[NSArray array] reachedEOL:nil];
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
	[[NSGarbageCollector defaultCollector] disable];
	regexps_tried = 0;
	regexps_overlapped = 0;
	regexps_matched = 0;

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
	BOOL extendedRange = NO;

	// reset attributes in the affected range
	[self resetAttributesInRange:aRange];

	NSUInteger lineno = 1;
	
	// highlight each line separately
	NSUInteger nextRange = aRange.location;
	while(nextRange < NSMaxRange(aRange))
	{
		NSUInteger end;
		[self getLineStart:NULL end:&end contentsEnd:NULL forLocation:nextRange];
		if(end == nextRange || end == NSNotFound)
			break;
		NSRange line = NSMakeRange(nextRange, end - nextRange);

		DEBUG(@"---> line number %i", lineno);

		if(extendedRange)
		{
			lastContinuedMatches = [self continuedMatchesForLocation:end];
			[self resetAttributesInRange:line];
		}

		continuedMatches = [self highlightLineInRange:line continueWithMatches:continuedMatches];
		nextRange = end;

		if(continuedMatches)
		{
			/* Mark the EOL character with the continuation patterns */
			[[self layoutManager] addTemporaryAttribute:ViContinuationAttributeName value:continuedMatches forCharacterRange:NSMakeRange(end - 1, 1)];
		}

		if(isRestarting && (extendedRange || nextRange >= NSMaxRange(aRange)) /*&& nextRange < [storage length]*/)
		{
			BOOL continuationMatchesHaveChanged = ![continuedMatches isEqualToPatternArray:lastContinuedMatches];
			if(continuationMatchesHaveChanged)
			{
				if(!extendedRange)
				{
					DEBUG(@"continuation matches at location %u have changed, and this is an incremental update", end);
					aRange.length = [storage length] - aRange.location;
					extendedRange = YES;
				}
			}
			else if(extendedRange)
			{
				NSLog(@"extended range and continuation matches are UNchanged, we're done at location %i (EOF = %i)",
				      nextRange, [storage length]);
				break;
			}
		}
		
		lineno++;
	}
	[[NSGarbageCollector defaultCollector] enable];
	DEBUG(@"tried regexps: %u", regexps_tried);
	DEBUG(@"matched regexps: %u", regexps_matched);
	DEBUG(@"overlapped regexps: %u", regexps_overlapped);
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
	DEBUG(@"%s highlighting range = %u + %u", _cmd, area.location, area.length);

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
	NSLog(@"start highlighting file");
	[storage beginEditing];
	[self highlightInRange:NSMakeRange(0, [[storage string] length]) restarting:NO];
	[storage endEditing];
	NSLog(@"finished highlighting file");
}

@end
