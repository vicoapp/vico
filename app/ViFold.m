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
		_children = [NSMutableSet set];
	}

	return self;
}

- (void)addChild:(ViFold *)childFold
{
	[_children addObject:childFold];
}

- (void)removeChild:(ViFold *)childFold
{
	[_children removeObject:childFold];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViFold %p: range %@>", self, NSStringFromRange(_range)];
}

@end
