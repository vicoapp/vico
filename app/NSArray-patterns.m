#import "NSArray-patterns.h"
#import "NSString-scopeSelector.h"
#import "ViSyntaxMatch.h"

@implementation NSArray (patterns)

- (BOOL)isEqualToPatternArray:(NSArray *)otherArray
{
	NSUInteger i, c = [self count];
	if (otherArray == self)
		return YES;
	if (c != [otherArray count])
		return NO;
	for (i = 0; i < c; i++)
		if ([[self objectAtIndex:i] pattern] != [[otherArray objectAtIndex:i] pattern])
			return NO;
	return YES;
}

- (BOOL)isEqualToStringArray:(NSArray *)otherArray
{
	NSInteger i, c = [self count];
	if (otherArray == self)
		return YES;
	if (c != [otherArray count])
		return NO;
	for (i = c - 1; i >= 0; i--)
		if (![[self objectAtIndex:i] isEqualToString:[otherArray objectAtIndex:i]])
			return NO;
	return YES;
}

- (BOOL)hasPrefix:(NSArray *)otherArray
{
	if ([self count] < [otherArray count])
		return NO;

	for (NSUInteger i = 0; i < [otherArray count]; i++)
		if (![[self objectAtIndex:i] isEqual:[otherArray objectAtIndex:i]])
			return NO;

	return YES;
}

- (BOOL)hasSuffix:(NSArray *)otherArray
{
	NSInteger j = [self count] - [otherArray count];
	if (j < 0)
		return NO;

	for (NSInteger i = 0; i < [otherArray count]; i++)
		if (![[self objectAtIndex:j] isEqual:[otherArray objectAtIndex:i]])
			return NO;

	return YES;
}

@end

