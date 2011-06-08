@class ViJumpList;
@class ViJump;

@protocol ViJumpListDelegate
- (void)jumpList:(ViJumpList *)aJumpList goto:(ViJump *)jump;
- (void)jumpList:(ViJumpList *)aJumpList added:(ViJump *)jump;
@end

@interface ViJump : NSObject
{
	NSURL *url;
	NSUInteger line, column;
	__weak NSView *view;
}
@property(nonatomic,readonly, assign) NSURL *url;
@property(nonatomic,readonly) NSUInteger line;
@property(nonatomic,readonly) NSUInteger column;
@property(nonatomic,readonly, assign) __weak NSView *view;
- (ViJump *)initWithURL:(NSURL *)aURL
                   line:(NSUInteger)aLine
                 column:(NSUInteger)aColumn
                   view:(NSView *)aView;
@end

@interface ViJumpList : NSObject
{
	NSMutableArray *jumps;
	NSInteger position;
	id<ViJumpListDelegate> delegate;
}
@property(nonatomic,readwrite, assign) id<ViJumpListDelegate> delegate;
- (BOOL)pushURL:(NSURL *)url
           line:(NSUInteger)line
         column:(NSUInteger)column
           view:(NSView *)aView;
- (BOOL)atBeginning;
- (BOOL)atEnd;
- (BOOL)forwardToURL:(NSURL **)urlPtr
                line:(NSUInteger *)linePtr
              column:(NSUInteger *)columnPtr
                view:(NSView **)viewPtr;
- (BOOL)backwardToURL:(NSURL **)urlPtr
                 line:(NSUInteger *)linePtr
               column:(NSUInteger *)columnPtr
                 view:(NSView **)viewPtr;
@end

