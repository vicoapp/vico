#import "ViFold.h"

NSString *const ViFoldedAttributeName = @"ViFoldedAttribute";
NSString *const ViFoldAttributeName = @"ViFoldAttribute";

inline ViFold *closestCommonParentFold(ViFold *firstFold, ViFold *secondFold)
{
	if (firstFold == secondFold) {
		return firstFold;
	}
	if ([firstFold hasParent:secondFold]) {
		return secondFold;
	}
	if ([secondFold hasParent:firstFold]) {
		return firstFold;
	}

	ViFold *currentFold = secondFold;
	while (currentFold && ! [firstFold hasParent:currentFold]) {
		currentFold = currentFold.parent;
	}

	if (! currentFold) {
		currentFold = firstFold;
		while (currentFold && ! [secondFold hasParent:currentFold]) {
			currentFold = currentFold.parent;
		}
	}

	return currentFold;
}

inline void addChildToFold(ViFold *parentFold, ViFold *childFold)
{
	if (parentFold == childFold)
		return;

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

+ (ViFold *)fold
{
	return [[super alloc] init];
}

- (ViFold *)init
{
	if (self = [super init]) {
		_depth = 1;
		_open = YES;
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

- (ViFold *)topmostParentWithParent:(ViFold *)markerParent
{
	ViFold *currentFold = self;
	while (currentFold && currentFold.parent != markerParent)
		currentFold = currentFold.parent;

	return currentFold;
}

- (NSString *)description
{
	if (_parent)
		return [NSString stringWithFormat:@"<ViFold %p: parent %@>",
										  self,
										  _parent];
	else
		return [NSString stringWithFormat:@"<ViFold %p>",
										  self];
}

@end
