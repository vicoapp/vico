#import "ViURLManager.h"

@interface ViHTTPDeferred : NSObject <ViDeferred>
{
	NSURLConnection *conn;
	NSURLRequest *request;
	NSMutableData *connData;
	void (^dataCallback)(NSData *);
	void (^completionCallback)(NSURL *, NSDictionary *, NSError *);
	NSUInteger receivedContentLength;
	NSInteger expectedContentLength;
	id<ViDeferredDelegate> delegate;
	BOOL finished;
}

- (void)cancel;
- (void)wait;
- (CGFloat)progress;
@end

@interface ViHTTPURLHandler : NSObject <ViURLHandler>
{
}
@end