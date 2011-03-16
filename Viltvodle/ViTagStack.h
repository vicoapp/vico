@interface ViTagStack : NSObject
{
	NSMutableArray *stack;
}

- (void)pushFile:(NSString *)aFile line:(NSUInteger)aLine column:(NSUInteger)aColumn;
- (NSDictionary *)pop;

@end
