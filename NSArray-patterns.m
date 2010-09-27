#import "NSArray-patterns.h"
#import "NSString-scopeSelector.h"
#import "ViSyntaxMatch.h"

/* returns 10^x */
static inline u_int64_t tenpow(unsigned x)
{
	u_int64_t r = 1ULL;
	while(x--)
		r *= 10ULL;
	return r;
}

@implementation NSArray (patterns)

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

- (BOOL)isEqualToStringArray:(NSArray *)otherArray
{
	int i, c = [self count];
	if (otherArray == self)
		return YES;
	if (c != [otherArray count])
		return NO;
	for (i = c - 1; i >= 0; i--)
	{
		if (![[self objectAtIndex:i] isEqualToString:[otherArray objectAtIndex:i]])
			return NO;
	}
	return YES;
}

@end

