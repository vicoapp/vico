/** A marked location.
 */
@interface ViMark : NSObject
{
	NSUInteger location;
	NSUInteger line, column;
}

/** The line number of the mark. */
@property(nonatomic,readonly) NSUInteger line;
/** The column of the mark. */
@property(nonatomic,readonly) NSUInteger column;
/** The character index of the mark. */
@property(nonatomic,readonly) NSUInteger location;

- (ViMark *)initWithLocation:(NSUInteger)aLocation line:(NSUInteger)aLine column:(NSUInteger)aColumn;

@end
