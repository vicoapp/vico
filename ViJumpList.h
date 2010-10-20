@class ViJumpList;
@class ViJump;

@protocol ViJumpListDelegate
- (void)jumpList:(ViJumpList *)aJumpList goto:(ViJump *)jump;
@end

@interface ViJump : NSObject
{
	NSURL *url;
	NSUInteger line, column;
}
@property(readwrite, assign) NSURL *url;
@property(readwrite) NSUInteger line;
@property(readwrite) NSUInteger column;
- (ViJump *)initWithURL:(NSURL *)aURL line:(NSUInteger)aLine column:(NSUInteger)aColumn;
@end

@interface ViJumpList : NSObject
{
	NSMutableArray *jumps;
	NSUInteger position;
	id<ViJumpListDelegate> delegate;
}
@property(readwrite, assign) id<ViJumpListDelegate> delegate;
- (BOOL)pushURL:(NSURL *)url line:(NSUInteger)line column:(NSUInteger)column;
- (BOOL)forwardToURL:(NSURL **)urlPtr line:(NSUInteger *)linePtr column:(NSUInteger *)columnPtr;
- (BOOL)backwardToURL:(NSURL **)urlPtr line:(NSUInteger *)linePtr column:(NSUInteger *)columnPtr;
@end

