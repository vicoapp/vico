#import "ViTextView.h"
#import "ViLanguageStore.h"

@interface ViSyntaxMatch : NSObject
{
	OGRegularExpressionMatch *beginMatch;
	OGRegularExpressionMatch *endMatch;
	NSDictionary *pattern;
	int patternIndex;
}
- (id)initWithMatch:(OGRegularExpressionMatch *)aMatch andPattern:(NSDictionary *)aPattern atIndex:(int)i;
- (NSComparisonResult)sortByLocation:(ViSyntaxMatch *)match;
- (OGRegularExpression *)endRegexp;
- (NSUInteger)beginLocation;
- (NSUInteger)endLocation;
- (void)setEndMatch:(OGRegularExpressionMatch *)aMatch;
- (NSString *)scope;
- (NSRange)matchedRange;
- (NSDictionary *)pattern;
- (OGRegularExpressionMatch *)beginMatch;
- (OGRegularExpressionMatch *)endMatch;
- (int)patternIndex;
@end

@implementation ViSyntaxMatch
- (id)initWithMatch:(OGRegularExpressionMatch *)aMatch andPattern:(NSDictionary *)aPattern atIndex:(int)i
{
	self = [super init];
	if(self)
	{
		beginMatch = aMatch;
		pattern = aPattern;
		patternIndex = i;
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
	return [beginMatch rangeOfMatchedString].location;
}
- (NSUInteger)endLocation
{
	NSRange r = [endMatch rangeOfMatchedString];
	//NSLog(@"    endLocation = %u = max range of %u + %u", NSMaxRange(r), r.location, r.length);
	return NSMaxRange([endMatch rangeOfMatchedString]);
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
- (NSDictionary *)pattern
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
@end

@implementation ViTextView (syntax)

- (void)initHighlighting
{
	if(!syntax_initialized)
	{
		syntax_initialized = YES;

		theme = [[ViTheme alloc] initWithBundle:@"Mac Classic"];
		NSLog(@"theme = %@", theme);

		//language = [[ViLanguageStore defaultStore] languageForFilename:filename];
		NSLog(@"ViLanguage = %@", language);
	}
}

- (void)highlightMatches:(NSArray *)matches forScope:(NSString *)aScopeSelector
{
	NSDictionary *attributes = [theme attributeForScopeSelector:aScopeSelector];
	if(attributes)
	{
		OGRegularExpressionMatch *match;
		for(match in matches)
		{
			//NSLog(@"! highlighting single-line match [%@] with scope [%@] at location %u, length %u",
			//      [match matchedString], aScopeSelector, [match rangeOfMatchedString].location, [match rangeOfMatchedString].length);
			[[self layoutManager] addTemporaryAttributes:attributes
						   forCharacterRange:[match rangeOfMatchedString]];
		}
	}
}

- (void)highlightMatch:(ViSyntaxMatch *)aMatch toEnd:(NSUInteger)aLocation
{
	NSDictionary *attributes = [theme attributeForScopeSelector:[aMatch scope]];
	NSRange range = NSMakeRange([aMatch beginLocation], aLocation - [aMatch beginLocation]);
	NSString *matchedString = [[storage string] substringWithRange:range];
	if(attributes)
	{
		//NSLog(@"! highlighting multi-line match [%@] with scope [%@] at location %u, length %u",
		//      matchedString, [aMatch scope], range.location, range.length);
		[[self layoutManager] addTemporaryAttributes:attributes forCharacterRange:range];
	}
}

- (void)highlightMatch:(ViSyntaxMatch *)aMatch
{
	[self highlightMatch:aMatch toEnd:NSMaxRange([aMatch matchedRange])];
}

- (void)highlightSingleLineMatchesInRange:(NSRange)aRange
{
	//NSLog(@"%s searching single-line matches in range = %u + %u", _cmd, aRange.location, aRange.length);

	NSDictionary *pattern;
	for(pattern in [language patterns])
	{
		if([pattern objectForKey:@"matchRegexp"])
		{
			OGRegularExpression *matchRegexp = [pattern objectForKey:@"matchRegexp"];
			NSArray *matches = [matchRegexp allMatchesInString:[storage string] range:aRange];
			//NSLog(@"%i matches for match regexp [%@]", [matches count], [pattern objectForKey:@"match"]);
			[self highlightMatches:matches forScope:[pattern objectForKey:@"name"]];
		}
	}
}

- (void)highlightCaptures:(NSString *)captureType inPattern:(NSDictionary *)pattern withMatch:(OGRegularExpressionMatch *)aMatch
{
	NSDictionary *captures = [pattern objectForKey:[NSString stringWithFormat:@"%@Captures", captureType]];
	if(captures == nil)
		captures = [pattern objectForKey:@"captures"];
	if(captures)
	{
		NSString *key;
		for(key in [captures allKeys])
		{
			NSDictionary *capture = [captures objectForKey:key];
			//NSLog(@"  found %@ capture %i [%@] with scope [%@]",
			//	captureType, [key intValue], [aMatch substringAtIndex:[key intValue]], [capture objectForKey:@"name"]);
			NSDictionary *attributes = [theme attributeForScopeSelector:[capture objectForKey:@"name"]];
			if(attributes)
			{
				//NSLog(@"! highlighting %@ capture [%@] as [%@]", captureType, [aMatch substringAtIndex:[key intValue]], [capture objectForKey:@"name"]);
				[[self layoutManager] addTemporaryAttributes:attributes
							   forCharacterRange:[aMatch rangeOfSubstringAtIndex:[key intValue]]];
			}
		}
	}
}

- (void)highlightBeginCapturesInMatch:(ViSyntaxMatch *)aMatch
{
	[self highlightCaptures:@"begin" inPattern:[aMatch pattern] withMatch:[aMatch beginMatch]];
}

- (void)highlightEndCapturesInMatch:(ViSyntaxMatch *)aMatch
{
	[self highlightCaptures:@"end" inPattern:[aMatch pattern] withMatch:[aMatch endMatch]];
}

/* returns YES if matches to EOL (ie, incomplete match)
 */
- (BOOL)searchEndForMatch:(ViSyntaxMatch *)viMatch fromLocation:(NSUInteger)lastLocation inRange:(NSRange)aRange
{
	NSLog(@"  searching for end match for beginning [%@] in range %u + %u, lastLocation = %u",
	      [[viMatch beginMatch] matchedString], aRange.location, aRange.length, lastLocation);
	OGRegularExpression *endRegexp = [viMatch endRegexp];
	if(endRegexp)
	{
		NSRange range = aRange;
		range.location = [viMatch beginLocation] + 1;
		range.length = NSMaxRange(aRange) - range.location;
		// just get the first match
		OGRegularExpressionMatch *endMatch = [endRegexp matchInString:[storage string] range:range];
		[viMatch setEndMatch:endMatch];
		if(endMatch == nil)
		{
			//NSLog(@"%s got match from %u to EOL (%u)", _cmd, [viMatch beginLocation], NSMaxRange(range));
			[self highlightMatch:viMatch toEnd:NSMaxRange(range)];
			return YES;
		}
		else
		{
			//NSLog(@"got end match for beginning [%@], endregexp=[%@]", [[viMatch beginMatch] matchedString], [[viMatch pattern] objectForKey:@"end"]);
			[self highlightMatch:viMatch];
			[self highlightEndCapturesInMatch:viMatch];
		}
	}

	return NO;
}

- (ViSyntaxMatch *)highlightLineInRange:(NSRange)aRange continueWithMatch:(ViSyntaxMatch *)continuedMatch
{
	NSString *line = [[storage string] substringWithRange:aRange];
	NSLog(@"%s range = %u + %u => (%@)", _cmd, aRange.location, aRange.length, line);
	NSUInteger lastLocation = aRange.location;

	if(continuedMatch)
	{
		if([self searchEndForMatch:continuedMatch fromLocation:aRange.location inRange:aRange] == YES)
			return continuedMatch;
		lastLocation = [continuedMatch endLocation] + 1;

		// adjust aRange
		aRange.length = (aRange.location + aRange.length) - lastLocation;
		if(aRange.length <= 0)
			return NO;
		aRange.location = lastLocation;
	}

	
	// search for beginnings of multi-line patterns
	NSMutableArray *matchingMultilinePatterns = [[NSMutableArray alloc] init];
	NSDictionary *pattern;
	int i = 0;
	for(pattern in [language patterns])
	{
		if([pattern objectForKey:@"beginRegexp"])
		{
			OGRegularExpression *beginRegexp = [pattern objectForKey:@"beginRegexp"];
			NSArray *matches = [beginRegexp allMatchesInString:[storage string] range:aRange];
			//NSLog(@"%i matches for begin regexp [%@] at patternIndex %i", [matches count], [pattern objectForKey:@"begin"], i);
			OGRegularExpressionMatch *match;
			for(match in matches)
			{
				ViSyntaxMatch *viMatch = [[ViSyntaxMatch alloc] initWithMatch:match andPattern:pattern atIndex:i];
				[matchingMultilinePatterns addObject:viMatch];
			}
		}
		++i;
	}
	//NSLog(@"%s sorting %u begin matches", _cmd, [matchingMultilinePatterns count]);
	[matchingMultilinePatterns sortUsingSelector:@selector(sortByLocation:)];

	// search for matching ends of multi-line patterns
	ViSyntaxMatch *viMatch;
	for(viMatch in matchingMultilinePatterns)
	{
		//NSLog(@"-> testing begin-match [%@] at location %u, patternIndex %i",
		//      [[viMatch beginMatch] matchedString], [viMatch beginLocation], [viMatch patternIndex]);
		if([viMatch beginLocation] >= lastLocation)
		{
			// highlight keywords between end of last match and start of this match
			[self highlightSingleLineMatchesInRange:NSMakeRange(lastLocation, [viMatch beginLocation] - lastLocation)];
			[self highlightBeginCapturesInMatch:viMatch];
			
			if([self searchEndForMatch:viMatch fromLocation:lastLocation inRange:aRange] == YES)
				return viMatch;

			lastLocation = [viMatch endLocation] + 1;
			// just return if we passed our line range
			if(lastLocation >= NSMaxRange(aRange))
				return nil;
		}
		else
		{
			NSLog(@"skipping embedded begin-match [%@]", [[viMatch beginMatch] matchedString]);
		}
	}

	// highlight keywords after any multi-line matches on this line
	if(lastLocation < NSMaxRange(aRange))
	{
		[self highlightSingleLineMatchesInRange:NSMakeRange(lastLocation, NSMaxRange(aRange) - lastLocation)];
	}

	return nil;
}

- (void)highlightInRange:(NSRange)aRange
{
	NSLog(@"%s range = %u + %u", _cmd, aRange.location, aRange.length);

	if(!syntax_initialized)
		[self initHighlighting];

	[[self layoutManager] removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:aRange];

	// highlight each line separately
	NSUInteger nextRange = aRange.location;
	ViSyntaxMatch *continuedMatch = nil;
	while(nextRange < NSMaxRange(aRange))
	{
		NSUInteger end;
		[self getLineStart:NULL end:&end contentsEnd:NULL forLocation:nextRange];
		if(end == nextRange || end == NSNotFound)
			break;
		NSRange line = NSMakeRange(nextRange, end - nextRange);
		continuedMatch = [self highlightLineInRange:line continueWithMatch:continuedMatch];
		nextRange = NSMaxRange(line);
	}
}

- (void)highlightInWrappedRange:(NSValue *)wrappedRange
{
	[self highlightInRange:[wrappedRange rangeValue]];
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
	NSLog(@"%s begin highlighting", _cmd);
	[storage beginEditing];
	[self highlightInRange:NSMakeRange(0, [[storage string] length])];
	[storage endEditing];
	NSLog(@"%s end highlighting", _cmd);
}

@end
