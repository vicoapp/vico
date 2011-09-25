#import "ViHTTPURLHandler.h"
#import "ViError.h"
#include "logging.h"

@implementation ViHTTPDeferred

@synthesize delegate = _delegate;

- (id)initWithURL:(NSURL *)aURL
	   onData:(void (^)(NSData *))aDataCallback
     onCompletion:(void (^)(NSURL *, NSDictionary *, NSError *))aCompletionCallback
{
	if ((self = [super init]) != nil) {
		_connData = [[NSMutableData alloc] init];
		_dataCallback = [aDataCallback copy];
		_completionCallback = [aCompletionCallback copy];
		_request = [[NSURLRequest alloc] initWithURL:aURL];
		_conn = [[NSURLConnection alloc] initWithRequest:_request
							delegate:self];
		DEBUG(@"conn = %@", _conn);
	}
	return self;
}

- (void)dealloc
{
	[_connData release];
	[_dataCallback release];
	[_completionCallback release];
	[_request release];
	[_conn release];
	[super dealloc];
}

- (void)finishWithError:(NSError *)error
{
	DEBUG(@"finished on conn %@, callback %p, error %@", _conn, _completionCallback, error);

	if (_completionCallback) {
		NSDictionary *attributes = nil;
		if (!error && [[_request URL] isFileURL]) {
			NSFileManager *fm = [[NSFileManager alloc] init];
			attributes = [fm attributesOfItemAtPath:[[_request URL] path]
							  error:&error];
			[fm release];
		}
		_completionCallback([_request URL], attributes, error);
	}

	[_completionCallback release];
	_completionCallback = NULL;

	[_dataCallback release];
	_dataCallback = NULL;

	[_connData release];
	_connData = nil;

	[_request release];
	_request = nil;

	[_conn release];
	_conn = nil;

	_finished = YES;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
#ifndef NO_DEBUG
	DEBUG(@"received response %@", response);
	if ([response isKindOfClass:[NSHTTPURLResponse class]])
		DEBUG(@"http headers: %@", [(NSHTTPURLResponse *)response allHeaderFields]);
#endif
	_expectedContentLength = [response expectedContentLength];
#ifndef NO_DEBUG
	if (_expectedContentLength != NSURLResponseUnknownLength && _expectedContentLength > 0)
		DEBUG(@"expecting %lld bytes", _expectedContentLength);
#endif
}

- (CGFloat)progress
{
	if (_expectedContentLength != NSURLResponseUnknownLength && _expectedContentLength > 0)
		return (CGFloat)_receivedContentLength / (CGFloat)_expectedContentLength;
	return -1.0;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	_receivedContentLength += [data length];
	DEBUG(@"received %lu bytes: %.1f%%", [data length], [self progress] * 100);
	[_connData appendData:data];
	if (_dataCallback)
		_dataCallback(data);
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
	[_conn cancel];

	/* Prevent error display. */
	[self finishWithError:[NSError errorWithDomain:NSCocoaErrorDomain
                                                  code:NSUserCancelledError
                                              userInfo:nil]];
}

- (void)wait
{
	while (!_finished) {
		DEBUG(@"request %@ not finished yet", self);
		[[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
	}
	DEBUG(@"request %@ is finished", self);
}

@end


@implementation ViHTTPURLHandler

- (BOOL)respondsToURL:(NSURL *)aURL
{
	return [[aURL scheme] isEqualToString:@"file"] ||
	       [[aURL scheme] isEqualToString:@"http"] ||
	       // [[aURL scheme] isEqualToString:@"https"] ||
	       [[aURL scheme] isEqualToString:@"ftp"];
}

- (NSURL *)normalizeURL:(NSURL *)aURL
{
	return [aURL absoluteURL];
}

- (id<ViDeferred>)dataWithContentsOfURL:(NSURL *)aURL
				 onData:(void (^)(NSData *))dataCallback
			   onCompletion:(void (^)(NSURL *, NSDictionary *, NSError *))completionCallback
{
	DEBUG(@"url = %@", aURL);
	ViHTTPDeferred *deferred = [[ViHTTPDeferred alloc] initWithURL:aURL
								onData:dataCallback
							  onCompletion:completionCallback];
	return [deferred autorelease];
}

@end
