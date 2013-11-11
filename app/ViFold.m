#import "ViFold.h"

inline void addChildToFold(ViFold *parentFold, ViFold *childFold)
{
	parentFold.range = NSUnionRange(parentFold.range, childFold.range);
	[parentFold addChild:childFold];
	childFold.parent = parentFold;
	childFold.depth += 1;
}

inline void addTopmostParentToFold(ViFold *parentFold, ViFold *nestedChildFold)
{
	ViFold *topmostFold = nestedChildFold;
	while (topmostFold.parent)
		topmostFold = topmostFold.parent;

	addChildToFold(parentFold, topmostFold);
}

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
		_parent = nil;
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
