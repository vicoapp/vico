#import "TxmtURLProtocol.h"
#import "ViDocument.h"
#include "logging.h"

@implementation TxmtURLProtocol
	
+ (void)registerProtocol
{
	static BOOL inited = NO;
	if (!inited) {
		[NSURLProtocol registerClass:[TxmtURLProtocol class]];
		inited = YES;
	}
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)theRequest
{
	NSString *theScheme = [[theRequest URL] scheme];
	return ([theScheme caseInsensitiveCompare:@"txmt"] == NSOrderedSame ||
		[theScheme caseInsensitiveCompare:@"vico"] == NSOrderedSame);
}

/*
 * If canInitWithRequest returns true, then webKit will call your
 * canonicalRequestForRequest method so you have an opportunity to
 * modify the NSURLRequest before processing the request.
 */
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
	/*
	 * We don't do any special processing here, though we include this
	 * method because all subclasses must implement this method.
	 */
	return request;
}

- (void)finalize
{
	if (client)
		CFRelease(client);
	[super finalize];
}

+ (NSURL *)parseURL:(NSURL *)url intoLineNumber:(NSNumber **)outLineNumber
{
	NSURL *openURL = nil;

	if ([[url scheme] caseInsensitiveCompare:@"txmt"] != NSOrderedSame &&
	    [[url scheme] caseInsensitiveCompare:@"vico"] != NSOrderedSame)
		return url;

	if ([[url host] isEqualToString:@"open"]) {
		NSArray *components = [[url query] componentsSeparatedByString:@"&"];
		NSString *line = nil;
		for (NSString *comp in components) {
			NSArray *tmp = [comp componentsSeparatedByString:@"="];
			if ([[tmp objectAtIndex:0] isEqualToString:@"url"]) {
				/* Need to unescape/escape since bundles also escape '/', and NSURL doesn't like that. */
				NSString *s = [[tmp objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
				s = [s stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
				openURL = [NSURL URLWithString:s];
			} else if ([[tmp objectAtIndex:0] isEqualToString:@"line"])
				line = [tmp objectAtIndex:1];
		}

		if (outLineNumber)
			*outLineNumber = [NSNumber numberWithInteger:[line integerValue]];
	} else if ([[url host] isEqualToString:@"credits"]) {
		NSString *p = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Resources/Credits.txt"];
		openURL = [NSURL fileURLWithPath:p];
		if (outLineNumber)
			*outLineNumber = [NSNumber numberWithInteger:0];
	}

	return openURL;
}

- (void)startLoading
{
	/*
	 * Workaround for bug in NSURLRequest:
	 * http://stackoverflow.com/questions/1112869/how-to-avoid-reference-count-underflow-in-nscfurlprotocolbridge-in-custom-nsurlp/4679837#4679837
	 */
	if (client)
		CFRelease(client);
	client = [self client];
	CFRetain(client);

	NSURLRequest *request = [self request];
	NSURL *url = [request URL];

	NSNumber *lineNumber = nil;
	NSURL *openURL = [TxmtURLProtocol parseURL:url intoLineNumber:&lineNumber];
	if (openURL) {
		SEL sel = @selector(gotoURL:lineNumber:);
		ViWindowController *winCon = [ViWindowController currentWindowController];
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[winCon methodSignatureForSelector:sel]];
		[invocation setSelector:sel];
		[invocation setArgument:&openURL atIndex:2];
		[invocation setArgument:&lineNumber atIndex:3];
		[invocation retainArguments];
		[invocation performSelectorOnMainThread:@selector(invokeWithTarget:)
					     withObject:winCon
					  waitUntilDone:NO];
	}

	/*
	 * This URL always fails. We only want the side effect of opening a file.
	 */

	NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorResourceUnavailable userInfo:nil];
	[client URLProtocol:self didFailWithError:error];
}

- (void)stopLoading
{
}

@end

