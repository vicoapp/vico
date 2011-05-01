#import "ViURLManager.h"

@interface ViHTTPDeferred : NSObject <ViDeferred>
{
	NSURLConnection *conn;
	NSMutableData *connData;
	void (^dataCallback)(NSData *data);
	void (^completionCallback)(NSError *error);
	NSUInteger receivedContentLength, expectedContentLength;
	id<ViDeferredDelegate> delegate;
}

- (void)cancel;
- (CGFloat)progress;
@end

@interface ViHTTPURLHandler : NSObject <ViURLHandler>
{
}
@end