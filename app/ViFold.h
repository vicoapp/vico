/**
 * ViFold contains information about a given fold in a document. It's most
 * important information is the start and end of the fold, and the parent
 * fold (if any), as well as the child folds (if any). It also stores the
 * fold depth, which is a number indicating how many parents exist higher
 * in the fold hierarchy above this fold. A top-level fold should have a
 * depth of 0.
 *
 * It also stores state information; specifically, whether the fold is open
 * or closed.
 */
@interface ViFold : NSObject
{
	NSMutableSet *_children;
}

@property (nonatomic) NSRange range;
@property (nonatomic) BOOL isOpen;
@property (nonatomic) ViFold *parent;
@property (nonatomic) NSUInteger depth;
@property (nonatomic,readonly) NSSet *children;

+ (ViFold *)foldWithRange:(NSRange)range;
- (ViFold *)initWithRange:(NSRange)range;

- (void)addChild:(ViFold *)childFold;
- (void)removeChild:(ViFold *)childFold;

@end
