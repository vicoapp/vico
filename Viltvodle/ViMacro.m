#import "ViMacro.h"
#import "NSString-additions.h"

@implementation ViMacro

@synthesize mapping;

+ (id)macroWithMapping:(ViMapping *)aMapping prefix:(NSArray *)prefixKeys
{
	return [[ViMacro alloc] initWithMapping:aMapping prefix:prefixKeys];
}

- (id)initWithMapping:(ViMapping *)aMapping prefix:(NSArray *)prefixKeys
{
	if ((self = [super init])) {
		mapping = aMapping;
		ip = 0;
		NSArray *macroKeys = [aMapping.macro keyCodes];
		if ([prefixKeys count] > 0)
			keys = [prefixKeys arrayByAddingObjectsFromArray:macroKeys];
		else
			keys = macroKeys;
	}

	return self;
}

- (NSInteger)pop
{
	if (ip >= [keys count])
		return -1LL;
	return [[keys objectAtIndex:ip++] integerValue];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViMacro: %@>",
	    [NSString stringWithKeySequence:keys]];
}

@end
