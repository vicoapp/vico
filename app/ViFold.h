extern NSString *const ViFoldedAttributeName;
extern NSString *const ViFoldAttributeName;

/**
 * ViFold contains information about a given fold in a document. Its most
 * important information is the start and end of the fold, and the parent
 * fold (if any), as well as the child folds (if any). It also stores the
 * fold depth, which is a number indicating how many parents exist higher
 * in the fold hierarchy above this fold. A top-level fold should have a
 * depth of 1.
 *
 * It also stores state information; specifically, whether the fold is open
 * or closed.
 */
@interface ViFold : NSObject
{
	NSMutableSet *_children;
}

@property (nonatomic,getter=isOpen) BOOL open;
@property (nonatomic) ViFold *parent;
@property (nonatomic) NSUInteger depth;
@property (nonatomic,readonly) NSSet *children;

+ (NSTextAttachment *)foldAttachment;

+ (ViFold *)fold;
- (ViFold *)init;

- (void)addChild:(ViFold *)childFold;
- (void)removeChild:(ViFold *)childFold;

- (BOOL)hasParent:(ViFold *)aFold;
/** @return The topmost parent fold of this fold. If this fold has no parent, returns this fold. */
- (ViFold *)topmostParent;

@end

/**
 * Checks `firstFold` and `secondFold` to find their closest common
 * parent. Notably, this can return either of the two folds depending
 * on how they related to each other. If they are equal, it will return
 * the first fold. If the second is a parent of the first, it will return
 * the second. If the first is a parent of the second, it will return the
 * first.
 *
 * Returns nil if there is no common parent.
 */
ViFold *closestCommonParentFold(ViFold *firstFold, ViFold *secondFold);
/**
 * Adds `childFold` to `parentFold` by updating both `childFold`'s parent
 * pointer AND `parentFold`'s child set.
 */
void addChildToFold(ViFold *parentFold, ViFold *childFold);
/**
 * Finds the topmost parent of `nestedChildFold`, which may be that fold
 * itself, and then adds it as a child to `parentFold`, as per
 * `addChildToFold`.
 */
void addTopmostParentToFold(ViFold *parentFold, ViFold *nestedChildFold);
