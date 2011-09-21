#import "ViSyntaxMatch.h"

@implementation ViSyntaxMatch

@synthesize patternIndex = _patternIndex;
@synthesize pattern = _pattern;
@synthesize beginLocation = _beginLocation;
@synthesize beginLength = _beginLength;
@synthesize beginMatch = _beginMatch;
@synthesize endMatch = _endMatch;

- (id)initWithMatch:(ViRegexpMatch *)aMatch andPattern:(NSMutableDictionary *)aPattern atIndex:(int)i
{
	if ((self = [super init]) != nil) {
		_beginMatch = [aMatch retain];
		_pattern = [aPattern retain];
		_patternIndex = i;
		if (aMatch) {
			_beginLocation = [aMatch rangeOfMatchedString].location;
			_beginLength = [aMatch rangeOfMatchedString].length;
		}
	}
	return self;
}

- (void)dealloc
{
	[_beginMatch release];
	[_endMatch release];
	[_pattern release];
	[super dealloc];
}

- (NSComparisonResult)sortByLocation:(ViSyntaxMatch *)anotherMatch
{
	if (_beginLocation < anotherMatch.beginLocation)
		return NSOrderedAscending;
	if (_beginLocation > anotherMatch.beginLocation)
		return NSOrderedDescending;
	if (_patternIndex < anotherMatch.patternIndex)
		return NSOrderedAscending;
	if (_patternIndex > anotherMatch.patternIndex)
		return NSOrderedDescending;
	return NSOrderedSame;
}

- (ViRegexp *)endRegexp
{
	return [_pattern objectForKey:@"endRegexp"];
}

- (void)setBeginLocation:(NSUInteger)aLocation
{
	// used for continued multi-line matches
	_beginLocation = aLocation;
	_beginLength = 0;
}

- (NSUInteger)endLocation
{
	if (_endMatch)
		return NSMaxRange([_endMatch rangeOfMatchedString]);
	else
		return NSMaxRange([_beginMatch rangeOfMatchedString]); // FIXME: ???
}

- (NSString *)scope
{
	return [_pattern objectForKey:@"name"];
}

- (NSRange)matchedRange
{
	return NSMakeRange(_beginLocation, [self endLocation] - _beginLocation);
}

- (BOOL)isSingleLineMatch
{
	return [_pattern objectForKey:@"begin"] == nil;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViSyntaxMatch: scope = %@>", [self scope]];
}

@end

