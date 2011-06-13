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
	return [scopeSelector matchesScopes:scopes];
}

@end

