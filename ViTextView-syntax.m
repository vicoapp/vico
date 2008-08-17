#import "ViTextView.h"

@interface ViSyntaxMatch : NSObject
{
	OGRegularExpressionMatch *beginMatch;
	OGRegularExpressionMatch *endMatch;
	NSDictionary *pattern;
}
- (id)initWithMatch:(OGRegularExpressionMatch *)aMatch andPattern:(NSDictionary *)aPattern;
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
@end

@implementation ViSyntaxMatch
- (id)initWithMatch:(OGRegularExpressionMatch *)aMatch andPattern:(NSDictionary *)aPattern
{
	self = [super init];
	if(self)
	{
		beginMatch = aMatch;
		pattern = aPattern;
	}
	return self;
}
- (NSComparisonResult)sortByLocation:(ViSyntaxMatch *)anotherMatch
{
	if([beginMatch index] < [anotherMatch beginLocation])
		return NSOrderedAscending;
	if([beginMatch index] > [anotherMatch beginLocation])
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
	return [endMatch rangeOfMatchedString].location;
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
@end

@implementation ViTextView (syntax)

- (void)initHighlighting
{
	if(!syntax_initialized)
	{
		syntax_initialized = YES;

		theme = [[ViTheme alloc] initWithBundle:@"Mac Classic"];
		NSLog(@"theme = %@", theme);

		language = [[ViLanguage alloc] initWithBundle:@"HTML"];
		NSLog(@"ViLanguage = %@", language);
	}
}

- (void)highlightMatches:(NSArray *)matches forScope:(NSString *)aScopeSelector
{
	NSDictionary *attributes = [theme attributeForScopeSelector:aScopeSelector];
	OGRegularExpressionMatch *match;
	for(match in matches)
	{
		[[self layoutManager] addTemporaryAttributes:attributes
					   forCharacterRange:[match rangeOfMatchedString]];
	}
}

- (void)highlightMatch:(ViSyntaxMatch *)aMatch toEnd:(NSUInteger)aLocation
{
	[[self layoutManager] addTemporaryAttributes:[theme attributeForScopeSelector:[aMatch scope]]
				   forCharacterRange:NSMakeRange([aMatch beginLocation], aLocation - [aMatch beginLocation])];
}

- (void)highlightMatch:(ViSyntaxMatch *)aMatch
{
	[[self layoutManager] addTemporaryAttributes:[theme attributeForScopeSelector:[aMatch scope]]
				   forCharacterRange:[aMatch matchedRange]];
}

- (void)highlightSingleLineMatchesInRange:(NSRange)aRange
{
	//NSLog(@"%s range = %u + %u", _cmd, aRange.location, aRange.length);

	NSDictionary *pattern;
	for(pattern in [language patterns])
	{
		if([pattern objectForKey:@"matchRegexp"])
		{
			OGRegularExpression *matchRegexp = [pattern objectForKey:@"matchRegexp"];
			NSArray *matches = [matchRegexp allMatchesInString:[storage string] range:aRange];
			[self highlightMatches:matches forScope:[pattern objectForKey:@"name"]];
		}
	}
}

- (void)highlightBeginCapturesInMatch:(ViSyntaxMatch *)aMatch
{
	NSDictionary *beginCaptures = [[aMatch pattern] objectForKey:@"beginCaptures"];
	if(beginCaptures == nil)
		beginCaptures = [[aMatch pattern] objectForKey:@"captures"];
	if(beginCaptures)
	{
		//NSLog(@"captures = %@", beginCaptures);
		NSString *key;
		OGRegularExpressionMatch *beginMatch = [aMatch beginMatch];
		for(key in [beginCaptures allKeys])
		{
			NSLog(@"  found begin capture %i [%@]", [key intValue], [beginMatch substringAtIndex:[key intValue]]);
			NSDictionary *capture = [beginCaptures objectForKey:key];
			NSDictionary *attributes = [theme attributeForScopeSelector:[capture objectForKey:@"name"]];
			if(attributes)
			{
				NSLog(@"  highlighting begin capture [%@] as [%@]", [beginMatch substringAtIndex:[key intValue]], [capture objectForKey:@"name"]);
				[[self layoutManager] addTemporaryAttributes:attributes
							   forCharacterRange:[beginMatch rangeOfSubstringAtIndex:[key intValue]]];
			}
		}
	}
}

- (NSUInteger)highlightLineInRange:(NSRange)aRange
{
	NSString *line = [[storage string] substringWithRange:aRange];
	NSLog(@"%s range = %u + %u => (%@)", _cmd, aRange.location, aRange.length, line);

	NSMutableArray *matchingMultilinePatterns = [[NSMutableArray alloc] init];
	NSDictionary *pattern;
	for(pattern in [language patterns])
	{
		if([pattern objectForKey:@"beginRegexp"])
		{
			OGRegularExpression *beginRegexp = [pattern objectForKey:@"beginRegexp"];
			NSArray *matches = [beginRegexp allMatchesInString:[storage string] range:aRange];
			NSLog(@"%i matches for begin regexp [%@]", [matches count], [pattern objectForKey:@"begin"]);
			OGRegularExpressionMatch *match;
			for(match in matches)
			{
				ViSyntaxMatch *viMatch = [[ViSyntaxMatch alloc] initWithMatch:match andPattern:pattern];
				[matchingMultilinePatterns addObject:viMatch];
			}
		}
	}
	NSLog(@"%s sorting %u begin matches", _cmd, [matchingMultilinePatterns count]);
	[matchingMultilinePatterns sortUsingSelector:@selector(sortByLocation:)];

	ViSyntaxMatch *viMatch;
	NSUInteger lastLocation = aRange.location;
	for(viMatch in matchingMultilinePatterns)
	{
		OGRegularExpression *endRegexp = [viMatch endRegexp];
		if(endRegexp && [viMatch beginLocation] >= lastLocation)
		{
			// highlight keywords between end of last match and start of this match
			[self highlightSingleLineMatchesInRange:NSMakeRange(lastLocation, [viMatch beginLocation] - lastLocation)];
			[self highlightBeginCapturesInMatch:viMatch];

			NSRange range = aRange;
			range.location = [viMatch beginLocation] + 1;
			range.length = NSMaxRange(aRange) - range.location;
			// just get the first match
			OGRegularExpressionMatch *endMatch = [endRegexp matchInString:[storage string] range:range];
			[viMatch setEndMatch:endMatch];
			if(endMatch == nil)
			{
				NSLog(@"%s got match from %u to EOL (%u)", _cmd, [viMatch beginLocation], NSMaxRange(range));
				[self highlightMatch:viMatch toEnd:NSMaxRange(range)];
				return NSMaxRange(range);
			}
			else
			{
				lastLocation = [viMatch endLocation];
				[self highlightMatch:viMatch];
				// just return if we passed our line range
				if([viMatch endLocation] > NSMaxRange(aRange))
					return [viMatch endLocation];
			}
		}
	}

	// highlight keywords after any multi-line matches on this line
	if(lastLocation < NSMaxRange(aRange))
	{
		[self highlightSingleLineMatchesInRange:NSMakeRange(lastLocation, NSMaxRange(aRange) - lastLocation)];
	}

	// return the end of this line
	return NSMaxRange(aRange);
}

- (void)highlightInRange:(NSRange)aRange
{
	NSLog(@"%s range = %u + %u", _cmd, aRange.location, aRange.length);

	if(!syntax_initialized)
		[self initHighlighting];

	[[self layoutManager] removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:aRange];

	// highlight each line separately
	NSUInteger nextRange = aRange.location;
	while(nextRange < NSMaxRange(aRange))
	{
		NSUInteger end;
		[self getLineStart:NULL end:&end contentsEnd:NULL forLocation:nextRange];
		if(end == nextRange || end == NSNotFound)
			break;
		NSRange line = NSMakeRange(nextRange, end - nextRange);
		nextRange = [self highlightLineInRange:line];
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
	NSLog(@"%s begin highlighting", _cmd);
	[storage beginEditing];
	[self highlightInRange:NSMakeRange(0, [[storage string] length])];
	[storage endEditing];
	NSLog(@"%s end highlighting", _cmd);
}

@end
