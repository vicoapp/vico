#import "ViTextView.h"
#import "ViLanguageStore.h"

//#define DEBUG(...)
#define DEBUG NSLog

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
@end



@interface ViTextView (syntax_private)
- (ViSyntaxMatch *)highlightLineInRange:(NSRange)aRange continueWithMatch:(ViSyntaxMatch *)continuedMatch inScope:(NSArray *)patterns;
@end

@implementation ViTextView (syntax)

- (void)initHighlighting
{
	if(!syntax_initialized)
	{
		syntax_initialized = YES;
		DEBUG(@"ViLanguage = %@", language);
	}
}

- (void)highlightMatch:(ViSyntaxMatch *)aMatch inRange:(NSRange)aRange
{
	NSDictionary *attributes = [theme attributeForScopeSelector:[aMatch scope]];
	if(attributes)
	{
		DEBUG(@"highlighting [%@] in range %u + %u", [aMatch scope], aRange.location, aRange.length);
		[[self layoutManager] addTemporaryAttributes:attributes forCharacterRange:aRange];
	}
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
		NSDictionary *attributes = [theme attributeForScopeSelector:[capture objectForKey:@"name"]];
		if(attributes)
		{
			NSRange r = [aMatch rangeOfSubstringAtIndex:[key intValue]];
			if(r.length > 0)
			{
				DEBUG(@" highlighting %@ [%@] in range %u + %u", captureType, [capture objectForKey:@"name"], r.location, r.length);
				[[self layoutManager] addTemporaryAttributes:attributes
							   forCharacterRange:r];
			}
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

- (ViSyntaxMatch *)highlightSubpatternsForPattern:(NSMutableDictionary *)pattern inRange:(NSRange)range
{
	if(range.length == 0)
		return nil;
	NSArray *subPatterns = [language expandedPatternsForPattern:pattern];
	if(subPatterns)
	{
		DEBUG(@"  higlighting (%i) subpatterns inside [%@] in range %u + %u", [subPatterns count], [pattern objectForKey:@"name"], range.location, range.length);
		return [self highlightLineInRange:range continueWithMatch:nil inScope:subPatterns];
	}
	return nil;
}

/* returns YES if matches to EOL (ie, incomplete multi-line match)
 */
- (BOOL)searchEndForMatch:(ViSyntaxMatch *)viMatch inRange:(NSRange)aRange
{
	OGRegularExpression *endRegexp = [viMatch endRegexp];
	if(endRegexp)
	{
		// just get the first match
		OGRegularExpressionMatch *endMatch = [endRegexp matchInString:[storage string] range:aRange];
		[viMatch setEndMatch:endMatch];
		if(endMatch == nil)
		{
			NSRange range;
			range.location = [viMatch beginLocation];
			range.length = NSMaxRange(aRange) - range.location;
			DEBUG(@"got match on [%@] from %u to EOL (%u)",
			      [[viMatch pattern] objectForKey:@"name"], [viMatch beginLocation], NSMaxRange(aRange));
			[self highlightMatch:viMatch inRange:range];

			// adjust aRange to be exclusive to a begin match
			range.location = [viMatch beginLocation] + [viMatch beginLength];
			range.length = NSMaxRange(aRange) - range.location;
			[self highlightSubpatternsForPattern:[viMatch pattern] inRange:range];

			return YES;
		}
		else
		{
			[self highlightMatch:viMatch];
			[self highlightEndCapturesInMatch:viMatch];
			
			// highlight sub-patterns within this match
			[self highlightSubpatternsForPattern:[viMatch pattern] inRange:[viMatch matchedRangeExclusive]];
		}
	}

	return NO;
}

- (ViSyntaxMatch *)highlightLineInRange:(NSRange)aRange continueWithMatch:(ViSyntaxMatch *)continuedMatch inScope:(NSArray *)patterns
{
	DEBUG(@"-----> line range = %u + %u", aRange.location, aRange.length);
	NSUInteger lastLocation = aRange.location;

	// should we continue on a multi-line match?
	if(continuedMatch)
	{
		DEBUG(@"continuing with match [%@]", [continuedMatch scope]);
		if([self searchEndForMatch:continuedMatch inRange:aRange] == YES)
			return continuedMatch;
		lastLocation = [continuedMatch endLocation];

		// adjust the line range
		if(lastLocation >= NSMaxRange(aRange))
			return NO;
		aRange.length = NSMaxRange(aRange) - lastLocation;
		aRange.location = lastLocation;
	}

	// keep an array of matches so we can sort it in order to skip matches embedded in other matches
	NSMutableArray *matchingPatterns = [[NSMutableArray alloc] init];
	NSMutableDictionary *pattern;
	if(patterns == nil)
	{
		// default to top-level patterns
		patterns = [language patternsForScope:nil];
	}
	int i = 0; // seems the patterns in textmate bundles are ordered
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

	// highlight non-overlapping matches on this line
	// if we have a multi-line match, search for the end match
	ViSyntaxMatch *viMatch;
	for(viMatch in matchingPatterns)
	{
		// skip overlapping matches
		if([viMatch beginLocation] < lastLocation)
			continue;

		if([viMatch isSingleLineMatch])
		{
			// this is a single-line match
			[self highlightMatch:viMatch];
			[self highlightCapturesInMatch:viMatch];
		}
		else
		{
			NSRange range = aRange;
			range.location = NSMaxRange([[viMatch beginMatch] rangeOfMatchedString]);
			range.length = NSMaxRange(aRange) - range.location;
			BOOL incompleteMatch = [self searchEndForMatch:viMatch inRange:range];
			[self highlightBeginCapturesInMatch:viMatch];				
			if(incompleteMatch == YES)
				return viMatch;
		}
		lastLocation = [viMatch endLocation];
		// just return if we passed our line range
		if(lastLocation >= NSMaxRange(aRange))
			return nil;
	}

	return nil;
}

- (ViSyntaxMatch *)continuedMatchForLocation:(NSUInteger)location
{
	ViSyntaxMatch *continuedMatch = nil;
	NSString *previousScope = [[self layoutManager] temporaryAttribute:ViScopeAttributeName
							  atCharacterIndex:IMAX(0, location - 1)
							    effectiveRange:NULL];
	if(previousScope)
	{
		continuedMatch = [[ViSyntaxMatch alloc] initWithMatch:nil
							   andPattern:[language patternForScope:previousScope]
							      atIndex:0];
		if([continuedMatch endRegexp] == nil)
		{
			/* skip single-line patterns */
			DEBUG(@"skipping previous scope [%@] (single-line) at location %u", previousScope, location);
			DEBUG(@"continued pattern = %@", [continuedMatch pattern]);
			return nil;
		}
		[continuedMatch setBeginLocation:location];
		DEBUG(@"detected previous scope [%@] at location %u", previousScope, location);
	}

	return continuedMatch;
}

- (void)highlightInRange:(NSRange)aRange restarting:(BOOL)isRestarting
{
	//DEBUG(@"%s range = %u + %u", _cmd, aRange.location, aRange.length);

	if(!syntax_initialized)
		[self initHighlighting];

	// if we're restarting, detect the previous scope so we can continue on a multi-line pattern, if any
	ViSyntaxMatch *continuedMatch = nil;
	if(isRestarting && aRange.location > 0)
	{
		continuedMatch = [self continuedMatchForLocation:aRange.location];
	}

	// reset attributes in the affected range
	NSDictionary *defaultAttributes = [NSDictionary dictionaryWithObject:[theme foregroundColor] forKey:NSForegroundColorAttributeName];
	[[self layoutManager] setTemporaryAttributes:defaultAttributes forCharacterRange:aRange];

	// highlight each line separately
	NSUInteger nextRange = aRange.location;
	while(nextRange < NSMaxRange(aRange))
	{
		NSUInteger end;
		[self getLineStart:NULL end:&end contentsEnd:NULL forLocation:nextRange];
		if(end == nextRange || end == NSNotFound)
			break;
		NSRange line = NSMakeRange(nextRange, end - nextRange);
		// force begin location to start of line for continued matches
		[continuedMatch setBeginLocation:nextRange];
		continuedMatch = [self highlightLineInRange:line continueWithMatch:continuedMatch inScope:nil];
		nextRange = end;
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

	// temporary attributes doesn't work right when called from a notification
	[self performSelector:@selector(highlightInWrappedRange:) withObject:[NSValue valueWithRange:area] afterDelay:0];
}

- (void)highlightEverything
{
	if(language == nil)
		return;
	DEBUG(@"%s begin highlighting", _cmd);
	[storage beginEditing];
	[self highlightInRange:NSMakeRange(0, [[storage string] length]) restarting:NO];
	[storage endEditing];
	DEBUG(@"%s end highlighting", _cmd);
}

@end
