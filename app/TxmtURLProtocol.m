/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "TxmtURLProtocol.h"
#import "ViDocument.h"
#import "NSObject+SPInvocationGrabbing.h"
#include "logging.h"

@implementation TxmtURLProtocol
	
+ (void)registerProtocol
{
	static BOOL __inited = NO;
	if (!__inited) {
		[NSURLProtocol registerClass:[TxmtURLProtocol class]];
		__inited = YES;
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
				if ([openURL isFileURL])
					openURL = [NSURL fileURLWithPath:[openURL path]];
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
	_client = [self client];

	NSURLRequest *request = [self request];
	NSURL *url = [request URL];

	NSNumber *lineNumber = nil;
	NSURL *openURL = [TxmtURLProtocol parseURL:url intoLineNumber:&lineNumber];
	if (openURL) {
		ViMark *m = [ViMark markWithURL:openURL line:[lineNumber unsignedIntegerValue] column:0];
		ViWindowController *windowController = [ViWindowController currentWindowController];
		[windowController performSelectorOnMainThread:@selector(gotoMark:) withObject:m waitUntilDone:NO];
	}

	/*
	 * This URL always fails. We only want the side effect of opening a file.
	 */

	NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorResourceUnavailable userInfo:nil];
	[_client URLProtocol:self didFailWithError:error];
}

- (void)stopLoading
{
}

@end

