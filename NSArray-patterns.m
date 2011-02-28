#import "NSArray-patterns.h"
#import "NSString-scopeSelector.h"
#import "ViSyntaxMatch.h"

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

- (NSString *)bestMatchForScopes:(NSArray *)scopes
{
	NSString *foundScopeSelector = nil;
	NSString *scopeSelector;
	u_int64_t highest_rank = 0;

	for (scopeSelector in self) {
		u_int64_t rank = [scopeSelector matchesScopes:scopes];
		if (rank > highest_rank) {
			foundScopeSelector = scopeSelector;
			highest_rank = rank;
		}
	}

	return foundScopeSelector;
}

@end

