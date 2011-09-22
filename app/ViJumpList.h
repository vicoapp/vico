@class ViJumpList;
@class ViJump;

@protocol ViJumpListDelegate
- (void)jumpList:(ViJumpList *)aJumpList goto:(ViJump *)jump;
- (void)jumpList:(ViJumpList *)aJumpList added:(ViJump *)jump;
@end



@interface ViJump : NSObject
{
	NSURL		*_url;
	NSUInteger	 _line;
	NSUInteger	 _column;
	__weak NSView	*_view;
}

@property(nonatomic,readonly,retain) NSURL *url;
@property(nonatomic,readonly) NSUInteger line;
@property(nonatomic,readonly) NSUInteger column;
@property(nonatomic,readonly,retain) __weak NSView *view;

- (ViJump *)initWithURL:(NSURL *)aURL
                   line:(NSUInteger)aLine
                 column:(NSUInteger)aColumn
                   view:(NSView *)aView;

@end




@interface ViJumpList : NSObject
{
	NSMutableArray			*_jumps;
	NSInteger			 _position;
	__weak id<ViJumpListDelegate>	 _delegate; // XXX: not retained!
}

@property(nonatomic,readwrite,assign) __weak id<ViJumpListDelegate> delegate;

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

- (void)enumerateJumpsBackwardsUsingBlock:(void (^)(ViJump *jump, BOOL *stop))block;

@end

