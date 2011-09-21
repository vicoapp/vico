#import "ViScope.h"
#import "NSString-scopeSelector.h"

@implementation ViScope

@synthesize range = _range;
@synthesize scopes = _scopes;
@synthesize attributes = _attributes;

+ (ViScope *)scopeWithScopes:(NSArray *)scopesArray range:(NSRange)aRange
{
	return [[[ViScope alloc] initWithScopes:scopesArray range:aRange] autorelease];
}

- (ViScope *)initWithScopes:(NSArray *)scopesArray
                      range:(NSRange)aRange
{
	if ((self = [super init]) != nil) {
		_scopes = [scopesArray retain]; // XXX: retain or copy?
		_range = aRange;
	}
	return self;
}

- (void)dealloc
{
	[_scopes release];
	[_attributes release];
	[super dealloc];
}

- (int)compareBegin:(ViScope *)otherContext
{
	if (self == otherContext)
		return 0;

	if (_range.location < otherContext.range.location)
		return -1;
	if (_range.location > otherContext.range.location)
		return 1;

	if (_range.length > otherContext.range.length)
		return -1;
	if (_range.length < otherContext.range.length)
		return 1;

	return 0;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViScope %p %@: %@>",
	    self, NSStringFromRange(_range),
	    [_scopes componentsJoinedByString:@" "]];
}

- (id)copyWithZone:(NSZone *)zone
{
	return [[[self class] allocWithZone:zone] initWithScopes:_scopes range:_range];
}

- (u_int64_t)match:(NSString *)scopeSelector
{
	if (scopeSelector == nil)
		return 1ULL;
	return [scopeSelector matchesScopes:_scopes];
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

- (BOOL)addScopeComponent:(NSString *)scopeComponent
{
	if (![_scopes containsObject:scopeComponent]) {
		[self setScopes:[_scopes arrayByAddingObject:scopeComponent]];
		return YES;
	}
	return NO;
}

@end

