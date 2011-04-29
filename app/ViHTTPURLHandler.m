#define FORCE_DEBUG
#import "ViHTTPURLHandler.h"
#import "ViError.h"
#include "logging.h"

@implementation ViHTTPDeferred

- (id)initWithURL:(NSURL *)aURL
	   onData:(void (^)(NSData *data))aDataCallback
     onCompletion:(void (^)(NSError *error))aCompletionCallback
{
	if ((self = [super init]) != nil) {
		connData = [NSMutableData data];
		dataCallback = Block_copy(aDataCallback);
		completionCallback = [aCompletionCallback copy];
		conn = [NSURLConnection connectionWithRequest:[NSURLRequest requestWithURL:aURL]
						     delegate:self];
		DEBUG(@"conn = %@", conn);
	}
	return self;
}

- (void)finishWithError:(NSError *)error
{
	DEBUG(@"finished on conn %@, callback %p", conn, completionCallback);

	if (completionCallback)
		completionCallback(error);

	completionCallback = NULL;
	dataCallback = NULL;
	connData = nil;
	conn = nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	DEBUG(@"received response %@", response);
	expectedContentLength = [response expectedContentLength];
	if (expectedContentLength != NSURLResponseUnknownLength && expectedContentLength > 0)
		DEBUG(@"expecting %lld bytes", expectedContentLength);
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
	[self finishWithError:[ViError errorWithFormat:@"Request cancelled"]];
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

- (id<ViDeferred>)dataWithContentsOfURL:(NSURL *)aURL
				 onData:(void (^)(NSData *data))dataCallback
			   onCompletion:(void (^)(NSError *error))completionCallback
{
	DEBUG(@"url = %@", aURL);
	ViHTTPDeferred *deferred = [[ViHTTPDeferred alloc] initWithURL:aURL
								onData:dataCallback
							  onCompletion:completionCallback];
	return deferred;
}

@end
