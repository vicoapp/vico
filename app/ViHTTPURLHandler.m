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
		_connData = [[NSMutableData alloc] init];
		_dataCallback = [aDataCallback copy];
		_completionCallback = [aCompletionCallback copy];
		_request = [[NSURLRequest alloc] initWithURL:aURL];
		_conn = [[NSURLConnection alloc] initWithRequest:_request
							delegate:self];
		DEBUG(@"conn = %@", _conn);
	}
	DEBUG_INIT();
	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
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
		}
		_completionCallback([_request URL], attributes, error);
	}

	_completionCallback = NULL;

	_dataCallback = NULL;

	_connData = nil;

	_request = nil;

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
	return deferred;
}

@end
