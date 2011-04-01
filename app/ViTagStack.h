@interface ViTagStack : NSObject
{
	NSMutableArray *stack;
}

- (void)pushURL:(NSURL *)url
           line:(NSUInteger)line
         column:(NSUInteger)column;
- (NSDictionary *)pop;

@end
