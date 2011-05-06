#import "ViHTTPURLHandler.h"
#import "ViError.h"
#include "logging.h"

@implementation ViHTTPDeferred

@synthesize delegate;

- (id)initWithURL:(NSURL *)aURL
	   onData:(void (^)(NSData *))aDataCallback
     onCompletion:(void (^)(NSURL *, NSDictionary *, NSError *))aCompletionCallback
{
	if ((self = [super init]) != nil) {
		connData = [NSMutableData data];
		dataCallback = Block_copy(aDataCallback);
		completionCallback = Block_copy(aCompletionCallback);
		request = [NSURLRequest requestWithURL:aURL];
		conn = [NSURLConnection connectionWithRequest:request
						     delegate:self];
		DEBUG(@"conn = %@", conn);
	}
	return self;
}

- (void)finishWithError:(NSError *)error
{
	DEBUG(@"finished on conn %@, callback %p, error %@", conn, completionCallback, error);

	if (completionCallback)
		completionCallback([request URL], nil, error);

	completionCallback = NULL;
	dataCallback = NULL;
	connData = nil;
	conn = nil;
	request = nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
#ifndef NO_DEBUG
	DEBUG(@"received response %@", response);
	if ([response isKindOfClass:[NSHTTPURLResponse class]])
		DEBUG(@"http headers: %@", [(NSHTTPURLResponse *)response allHeaderFields]);
#endif
	expectedContentLength = [response expectedContentLength];
#ifndef NO_DEBUG
	if (expectedContentLength != NSURLResponseUnknownLength && expectedContentLength > 0)
		DEBUG(@"expecting %lld bytes", expectedContentLength);
#endif
}

- (CGFloat)progress
{
	if (expectedContentLength != NSURLResponseUnknownLength && expectedContentLength > 0)
		return (CGFloat)receivedContentLength / (CGFloat)expectedContentLength;
	return -1.0;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	receivedContentLength += [data length];
	DEBUG(@"received %lu bytes: %.1f%%", [data length], [self progress] * 100);
	[connData appendData:data];
	if (dataCallback)
		dataCallback(data);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	[self finishWithError:nil];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	DEBUG(@"failed with error %@", error);
	[self finishWithError:error];
}

- (void)cancel
{
	[conn cancel];
	/* Prevent error display. */
	[self finishWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]];
}

@end


@implementation ViHTTPURLHandler

- (id)init
{
	if ((self = [super init]) != nil) {
	}

	return self;
}

- (BOOL)respondsToURL:(NSURL *)aURL
{
	return [[aURL scheme] isEqualToString:@"file"] ||
	       [[aURL scheme] isEqualToString:@"http"] ||
	       [[aURL scheme] isEqualToString:@"https"] ||
	       [[aURL scheme] isEqualToString:@"ftp"];
}

- (NSURL *)normalizeURL:(NSURL *)aURL
{
	return aURL;
}

- (id<ViDeferred>)dataWithContentsOfURL:(NSURL *)aURL
				 onData:(void (^)(NSData *))dataCallback
			   onCompletion:(void (^)(NSURL *, NSDictionary *, NSError *))completionCallback
{
	DEBUG(@"url = %@", aURL);
	ViHTTPDeferred *deferred = [[ViHTTPDeferred alloc] initWithURL:aURL
								onData:dataCallback
							  onCompletion:completionCallback];
	return deferred;
}

@end
