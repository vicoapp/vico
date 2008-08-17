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
	return [OGRegularExpression regularExpressionWithString:[pattern objectForKey:@"end"]];
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
@end

@implementation ViTextView (syntax)

- (void)initHighlighting
{
	if(!syntax_initialized)
	{
		syntax_initialized = YES;

		NSString *path = [[NSBundle mainBundle] pathForResource:@"Objective-C" ofType:@"tmLanguage"];
		NSDictionary *language = [NSDictionary dictionaryWithContentsOfFile:path];
		// NSLog(@"%s language = %@", _cmd, language);

		languagePatterns = [language objectForKey:@"patterns"];
		NSLog(@"%s got %i patterns", _cmd, [languagePatterns count]);
		NSDictionary *d;
		for(d in languagePatterns)
		{
			NSLog(@"%s got pattern for scope [%@]", _cmd, [d objectForKey:@"name"]);
			NSLog(@"%s %@", _cmd, d);
		}

		path = [[NSBundle mainBundle] pathForResource:@"Mac Classic" ofType:@"tmTheme"];
		theme = [NSDictionary dictionaryWithContentsOfFile:path];
		//NSLog(@"%s theme = %@", _cmd, theme);
		
		
		
		themeAttributes = [[NSMutableDictionary alloc] init];
		NSArray *settings = [theme objectForKey:@"settings"];
		NSDictionary *setting;
		for(setting in settings)
		{
			NSString *scope = [setting objectForKey:@"scope"];
			NSArray *scope_selectors = [scope componentsSeparatedByString:@", "];
			NSString *foreground = [[setting objectForKey:@"settings"] objectForKey:@"foreground"];
			if(foreground == nil)
				continue;
			NSLog(@"%s saving foreground color %@", _cmd, foreground);
			int r, g, b;
			if(sscanf([foreground UTF8String], "#%02X%02X%02X", &r, &g, &b) != 3)
				continue;
			NSColor *fgColor = [NSColor colorWithDeviceRed:(float)r/256.0 green:(float)g/256.0 blue:(float)b/256.0 alpha:1.0];
			NSDictionary *attrs = [NSDictionary dictionaryWithObject:fgColor forKey:NSForegroundColorAttributeName];
			for(scope in scope_selectors)
			{
				[themeAttributes setObject:attrs forKey:scope];
				NSLog(@"%s  %@ = %@", _cmd, scope, fgColor);
			}
		}
	}
}

- (NSDictionary *)attributeForScopeSelector:(NSString *)aScopeSelector
{
	NSString *scope;
	for(scope in [themeAttributes allKeys])
	{
		if([aScopeSelector hasPrefix:scope])
		{
			return [themeAttributes objectForKey:scope];
		}
	}
	return nil;
}

- (void)highlightMatches:(NSArray *)matches forScope:(NSString *)aScopeSelector
{
	NSDictionary *attributes = [self attributeForScopeSelector:aScopeSelector];
	OGRegularExpressionMatch *match;
	for(match in matches)
	{
		[[self layoutManager] addTemporaryAttributes:attributes
					   forCharacterRange:[match rangeOfMatchedString]];
	}
}

- (void)highlightMatch:(ViSyntaxMatch *)aMatch toEnd:(NSUInteger)aLocation
{
	[[self layoutManager] addTemporaryAttributes:[self attributeForScopeSelector:[aMatch scope]]
				   forCharacterRange:NSMakeRange([aMatch beginLocation], aLocation)];
}

- (void)highlightMatch:(ViSyntaxMatch *)aMatch
{
	[[self layoutManager] addTemporaryAttributes:[self attributeForScopeSelector:[aMatch scope]]
				   forCharacterRange:[aMatch matchedRange]];
}

- (void)highlightSingleLineMatchesInRange:(NSRange)aRange
{
	//NSLog(@"%s range = %u + %u", _cmd, aRange.location, aRange.length);

	NSDictionary *pattern;
	for(pattern in languagePatterns)
	{
		if([pattern objectForKey:@"match"])
		{
			OGRegularExpression *matchRegexp = [OGRegularExpression regularExpressionWithString:[pattern objectForKey:@"match"]];
			NSArray *matches = [matchRegexp allMatchesInString:[storage string] range:aRange];
			[self highlightMatches:matches forScope:[pattern objectForKey:@"name"]];
		}
	}
}

- (NSUInteger)highlightLineInRange:(NSRange)aRange
{
	//NSLog(@"%s range = %u + %u", _cmd, aRange.location, aRange.length);

	NSMutableArray *matchingMultilinePatterns = [[NSMutableArray alloc] init];
	NSDictionary *pattern;
	for(pattern in languagePatterns)
	{
		if([pattern objectForKey:@"begin"] && [pattern objectForKey:@"scope"])
		{
			OGRegularExpression *beginRegexp = [OGRegularExpression regularExpressionWithString:[pattern objectForKey:@"begin"]];
			NSArray *matches = [beginRegexp allMatchesInString:[storage string] range:aRange];
			OGRegularExpressionMatch *match;
			for(match in matches)
			{
				ViSyntaxMatch *viMatch = [[ViSyntaxMatch alloc] initWithMatch:match andPattern:pattern];
				[matchingMultilinePatterns addObject:viMatch];
			}
		}
	}
	[matchingMultilinePatterns sortUsingSelector:@selector(sortByLocation:)];

	ViSyntaxMatch *viMatch;
	NSUInteger lastLocation = aRange.location;
	for(viMatch in matchingMultilinePatterns)
	{
		OGRegularExpression *endRegexp = [viMatch endRegexp];
		if(endRegexp && [viMatch beginLocation] > lastLocation)
		{
			// highlight keywords between end of last match and start of this match
			[self highlightSingleLineMatchesInRange:NSMakeRange(lastLocation, [viMatch beginLocation] - lastLocation)];

			NSRange range = aRange;
			range.location = [viMatch beginLocation] + 1;
			range.length = [storage length] - range.location;
			// just get the first match
			OGRegularExpressionMatch *endMatch = [endRegexp matchInString:[storage string] options:OgreMultilineOption range:range];
			[viMatch setEndMatch:endMatch];
			if(endMatch == nil)
			{
				NSLog(@"%s got infinite match from %u", _cmd, [viMatch beginLocation]);
				[self highlightMatch:viMatch toEnd:[storage length] - 1];
				return [storage length];
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
	//[storage beginEditing];
	[self highlightInRange:NSMakeRange(0, [[storage string] length])];
	//[storage endEditing];
}

@end
