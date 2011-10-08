#import "ViURLManager.h"

@interface ViHTTPDeferred : NSObject <ViDeferred>
{
	NSURLConnection		*_conn;
	NSURLRequest		*_request;
	NSMutableData		*_connData;
	unsigned long long	 _receivedContentLength;
	long long		 _expectedContentLength;
	id<ViDeferredDelegate>	 _delegate;
	BOOL			 _finished;

	void (^_dataCallback)(NSData *);
	void (^_completionCallback)(NSURL *, NSDictionary *, NSError *);
}

- (void)cancel;
- (void)wait;
- (CGFloat)progress;
@end

@interface ViHTTPURLHandler : NSObject <ViURLHandler>
{
}
@end
