#import "NSString-scopeSelector.h"
#import <OgreKit/OgreKit.h>

/* returns 10^x */
static u_int64_t tenpow(unsigned x)
{
	u_int64_t r = 1ULL;
	while(x--)
		r *= 10ULL;
	return r;
}

@implementation NSString (scopeSelector)

- (u_int64_t)scopePartRankAtDepth:(int)depth
{
	u_int64_t rank = 0;
	int ndots = 0;
	int n;
	for(n = 0; n < [self length]; n++)
	{
		if([self characterAtIndex:n] == '.')
			ndots++;
	}
	if(ndots > 0)
		rank += ndots * tenpow(depth);
	return rank;
}

- (u_int64_t)matchesScopes:(NSArray *)scopes
{
	// check for empty scope selector
	if([self length] == 0)
		return 1ULL;

	// split the scope selector into descendants
	NSArray *descendants = [self componentsSeparatedByRegularExpressionString:@"\\s+"];

	u_int64_t rank = 0ULL;

	// find the depth of the match of the first descendant
	int i;
	for(i = 0; i < [scopes count]; i++)
	{
		// if we haven't matched by now, fail
		if([descendants count] + i > [scopes count])
			return 0;

		int j;
		for(j = 0; j < [descendants count]; j++)
		{
			NSString *scope = [scopes objectAtIndex:i+j];
			NSString *selector = [descendants objectAtIndex:j];
			//NSLog(@"comparing selector [%@] with scope [%@]", selector, scope);
			if([scope hasPrefix:selector])
			{
				// "Another 10^<depth> points is given for each additional part of the scope that is matched"
				rank += [selector scopePartRankAtDepth:i+1+j];

				// whole selector matched?
				if(j + 1 == [descendants count])
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
