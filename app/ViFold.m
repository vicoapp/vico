#import "ViFold.h"

@implementation ViFold

+ (ViFold *)foldWithRange:(NSRange)aRange
{
	return [[super alloc] initWithRange:aRange];
}

- (ViFold *)initWithRange:(NSRange)aRange
{
	if (self = [super init]) {
		_range = aRange;
		_isOpen = true;
	}

	return self;
}

- (void)addChild:(ViFold *)childFold
{
	// noop for now
}

- (void)removeChild:(ViFold *)childFold
{
	// noop for now
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViFold %p: range %@>", self, NSStringFromRange(_range)];
}

@end
