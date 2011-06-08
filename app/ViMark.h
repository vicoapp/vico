@interface ViMark : NSObject
{
	NSUInteger line, column;
}
@property(nonatomic,readonly) NSUInteger line;
@property(nonatomic,readonly) NSUInteger column;

- (ViMark *)initWithLine:(NSUInteger)aLine column:(NSUInteger)aColumn;

@end
