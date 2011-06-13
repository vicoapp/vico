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
		keys = [[aMapping.macro keyCodes] mutableCopy];
		if ([prefixKeys count] > 0)
			[keys replaceObjectsInRange:NSMakeRange(0, 0) withObjectsFromArray:prefixKeys];
	}

	return self;
}

- (void)push:(NSNumber *)keyCode
{
	[keys insertObject:keyCode atIndex:ip];
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
