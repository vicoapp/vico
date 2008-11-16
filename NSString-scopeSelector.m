#import "NSString-scopeSelector.h"
#import "NSArray-patterns.h"
#import "logging.h"

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
	NSArray *descendants = [self componentsSeparatedByString:@" "];
	
	return [descendants matchesScopes:scopes];

}

@end
