#import "ViFold.h"

NSString *const ViFoldedAttributeName = @"ViFoldedAttribute";

inline ViFold *closestCommonParentFold(ViFold *firstFold, ViFold *secondFold)
{
	if (firstFold == secondFold) {
		return firstFold;
	}

	ViFold *currentFold = secondFold;
	while (currentFold && ! [firstFold hasParent:currentFold]) {
		currentFold = currentFold.parent;
	}

	return currentFold;
}

inline void addChildToFold(ViFold *parentFold, ViFold *childFold)
{
	if (parentFold == childFold)
		return;

	parentFold.range = NSUnionRange(parentFold.range, childFold.range);
	[parentFold addChild:childFold];
	childFold.parent = parentFold;
	childFold.depth = parentFold.depth + 1;
}

inline void addTopmostParentToFold(ViFold *parentFold, ViFold *nestedChildFold)
{
	ViFold *topmostFold = nestedChildFold;
	while (topmostFold.parent)
		topmostFold = topmostFold.parent;

	addChildToFold(parentFold, topmostFold);
}

static NSTextAttachment *foldAttachment = nil;

@implementation ViFold

+ (NSTextAttachment *)foldAttachment
{
	if (! foldAttachment) {
		NSURL *foldImageURL = [[NSBundle mainBundle] URLForResource:@"tag" withExtension:@"png"];
		NSError *error = nil;
		NSFileWrapper *foldImageFile = [[NSFileWrapper alloc] initWithURL:foldImageURL options:0 error:&error];
		if (! error)
			foldAttachment = [[NSTextAttachment alloc] initWithFileWrapper:foldImageFile];
	}

	return foldAttachment;
}

+ (ViFold *)foldWithRange:(NSRange)aRange
{
	return [[super alloc] initWithRange:aRange];
}

- (ViFold *)initWithRange:(NSRange)aRange
{
	if (self = [super init]) {
		_range = aRange;
		_open = true;
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

- (BOOL)hasParent:(ViFold *)aFold
{
	ViFold *currentFold = _parent;
	while (currentFold && currentFold != aFold)
		currentFold = currentFold.parent;

	return currentFold == aFold;
}

- (ViFold *)topmostParent
{
	ViFold *currentFold = self;
	while (currentFold.parent)
		currentFold = currentFold.parent;

	return currentFold;
}

- (NSString *)description
{
	if (_parent)
		return [NSString stringWithFormat:@"<ViFold %p: range %@, parent %@>",
										  self,
										  NSStringFromRange(_range),
										  _parent];
	else
		return [NSString stringWithFormat:@"<ViFold %p: range %@>",
										  self,
										  NSStringFromRange(_range)];
}

@end
