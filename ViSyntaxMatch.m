#import "ViSyntaxMatch.h"

@implementation ViSyntaxMatch

@synthesize patternIndex;
@synthesize pattern;
@synthesize beginLocation;
@synthesize beginLength;
@synthesize beginMatch;
@synthesize endMatch;

- (id)initWithMatch:(ViRegexpMatch *)aMatch andPattern:(NSMutableDictionary *)aPattern atIndex:(int)i
{
	self = [super init];
	if (self)
	{
		beginMatch = aMatch;
		pattern = aPattern;
		patternIndex = i;
		if (aMatch)
		{
			beginLocation = [aMatch rangeOfMatchedString].location;
			beginLength = [aMatch rangeOfMatchedString].length;
		}
	}
	return self;
}

- (NSComparisonResult)sortByLocation:(ViSyntaxMatch *)anotherMatch
{
	if ([self beginLocation] < [anotherMatch beginLocation])
		return NSOrderedAscending;
	if ([self beginLocation] > [anotherMatch beginLocation])
		return NSOrderedDescending;
	if ([self patternIndex] < [anotherMatch patternIndex])
		return NSOrderedAscending;
	if ([self patternIndex] > [anotherMatch patternIndex])
		return NSOrderedDescending;
	return NSOrderedSame;
}

- (ViRegexp *)endRegexp
{
	return [pattern objectForKey:@"endRegexp"];
}

- (void)setEndMatch:(ViRegexpMatch *)aMatch
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
	if (endMatch)
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
	if (range.length < 0)
	{
		INFO(@"negative length, beginLocation = %u, endLocation = %u", [self beginLocation], [self endLocation]);
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

