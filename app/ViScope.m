#import "ViScope.h"
#import "NSString-scopeSelector.h"

@implementation ViScope

@synthesize range;
@synthesize scopes;
@synthesize attributes;

- (ViScope *)initWithScopes:(NSArray *)scopesArray
                      range:(NSRange)aRange
{
	if ((self = [super init]) != nil) {
		scopes = scopesArray;
		range = aRange;
	}
	return self;
}

- (int)compareBegin:(ViScope *)otherContext
{
	if (self == otherContext)
		return 0;

	if (range.location < otherContext.range.location)
		return -1;
	if (range.location > otherContext.range.location)
		return 1;

	if (range.length > otherContext.range.length)
		return -1;
	if (range.length < otherContext.range.length)
		return 1;

	return 0;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViScope %p %@: %@>",
	    self, NSStringFromRange(range),
	    [scopes componentsJoinedByString:@" "]];
}

- (id)copyWithZone:(NSZone *)zone
{
	return [[ViScope alloc] initWithScopes:scopes range:range];
}

- (u_int64_t)match:(NSString *)scopeSelector
{
	if (scopeSelector == nil)
		return 1ULL;
	return [scopeSelector matchesScopes:scopes];
}

- (NSString *)bestMatch:(NSArray *)scopeSelectors
{
	NSString *foundScopeSelector = nil;
	NSString *scopeSelector;
	u_int64_t highest_rank = 0;

	for (scopeSelector in scopeSelectors) {
		u_int64_t rank = [self match:scopeSelector];
		if (rank > highest_rank) {
			foundScopeSelector = scopeSelector;
			highest_rank = rank;
		}
	}

	return foundScopeSelector;
}

@end

