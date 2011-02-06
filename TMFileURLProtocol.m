#import "TMFileURLProtocol.h"

@implementation TMFileURLProtocol
	
+ (void)registerProtocol
{
	static BOOL inited = NO;
	if (!inited) {
		[NSURLProtocol registerClass:[TMFileURLProtocol class]];
		inited = YES;
	}
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)theRequest
{
	NSString *theScheme = [[theRequest URL] scheme];
	return ([theScheme caseInsensitiveCompare:@"tm-file"] == NSOrderedSame);
}

/*
 * If canInitWithRequest returns true, then webKit will call your
 * canonicalRequestForRequest method so you have an opportunity to
 * modify the NSURLRequest before processing the request.
 */
+(NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
	/*
	 * We don't do any special processing here, though we include this
	 * method because all subclasses must implement this method.
	 */
	return request;
}

- (void)startLoading
{
	NSURLRequest *request = [self request];
	NSURL *url = [request URL];

	NSFileManager *fm = [[NSFileManager alloc] init];
	NSInteger length = -1;

	NSData *data = [fm contentsAtPath:[url path]];
	if (data)
		length = [data length];

	NSURLResponse *response = [[NSURLResponse alloc] initWithURL:url
		MIMEType:@"text/html"
		expectedContentLength:length
		textEncodingName:nil];

	id<NSURLProtocolClient> client = [self client];

	[client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
	[client URLProtocol:self didLoadData:data];
	[client URLProtocolDidFinishLoading:self];

	if (data == nil) {
		NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorResourceUnavailable userInfo:nil];
		[client URLProtocol:self didFailWithError:error];
	}
}

- (void)stopLoading
{
}

@end

