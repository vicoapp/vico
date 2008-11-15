#import "ViSyntaxResult.h"

@implementation ViSyntaxResult

@synthesize scopes;
@synthesize range;

- (ViSyntaxResult *)initWithScopes:(NSArray *)scopeArray range:(NSRange)aRange
{
	self = [super init];
	if (self)
	{
		scopes = scopeArray;
		range = aRange;
	}
	return self;
}

@end
