@class ViMark;
@class ViJumpList;

@protocol ViJumpListDelegate
- (void)jumpList:(ViJumpList *)aJumpList goto:(ViMark *)jump;
- (void)jumpList:(ViJumpList *)aJumpList added:(ViMark *)jump;
@end



@interface ViJumpList : NSObject
{
	NSMutableArray			*_jumps;
	NSInteger			 _position;
	__weak id<ViJumpListDelegate>	 _delegate; // XXX: not retained!
}

@property(nonatomic,readwrite,assign) __weak id<ViJumpListDelegate> delegate;

- (BOOL)push:(ViMark *)newJump;

- (BOOL)atBeginning;
- (BOOL)atEnd;

- (ViMark *)forward;
- (ViMark *)backwardFrom:(ViMark *)fromJump;

- (void)enumerateJumpsBackwardsUsingBlock:(void (^)(ViMark *jump, BOOL *stop))block;

@end

