/** A marked location.
 */
@interface ViMark : NSObject
{
	NSUInteger line, column;
}

/** The line number of the mark. */
@property(nonatomic,readonly) NSUInteger line;
/** The column of the mark. */
@property(nonatomic,readonly) NSUInteger column;

- (ViMark *)initWithLine:(NSUInteger)aLine column:(NSUInteger)aColumn;

@end
