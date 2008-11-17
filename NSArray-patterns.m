#import "NSArray-patterns.h"
#import "NSString-scopeSelector.h"

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

- (u_int64_t)matchesScopes:(NSArray *)scopes
{
	u_int64_t rank = 0ULL;

	// find the depth of the match of the first descendant
	int i, c = [self count], sc = [scopes count];
	for (i = 0; i < sc; i++)
	{
		// if we haven't matched by now, fail
		if (c + i > sc)
			return 0;

		int j;
		for (j = 0; j < c; j++)
		{
			NSString *scope = [scopes objectAtIndex:i+j];
			NSString *selector = [self objectAtIndex:j];
			// DEBUG(@"comparing selector [%@] with scope [%@]", selector, scope);
			if ([scope hasPrefix:selector])
			{
				// "Another 10^<depth> points is given for each additional part of the scope that is matched"
#if 0
				rank += [selector scopePartRankAtDepth:i+1+j];
#else
				int ndots = 0;
				int n, sl = [selector length];
				for (n = 0; n < sl; n++)
				{
					if ([selector characterAtIndex:n] == '.')
						ndots++;
				}
				if (ndots > 0)
					rank += ndots * tenpow(i+1+j);
#endif

				// whole selector matched?
				if (j + 1 == c)
				{
					// the total depth rank is:
					rank += (i + 1 + j) * DEPTH_RANK;

					// "1 extra point is given for each extra descendant scope"
					rank += j;

					return rank;
				}
			}
			else
			{
				// this scope selector doesn't match here, start over
				rank = 0ULL;
				break;
			}
		}
	}

	return rank;
}

@end

