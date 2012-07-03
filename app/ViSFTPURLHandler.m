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

#import "ViSFTPURLHandler.h"
#import "SFTPConnectionPool.h"
#include "logging.h"

@implementation ViSFTPURLHandler

- (BOOL)respondsToURL:(NSURL *)aURL
{
	return [[aURL scheme] isEqualToString:@"sftp"];
}

- (NSURL *)normalizeURL:(NSURL *)aURL
{
	return [[SFTPConnectionPool sharedPool] normalizeURL:aURL];
}

- (NSString *)stringByAbbreviatingWithTildeInPath:(NSURL *)aURL
{
	return [[SFTPConnectionPool sharedPool] stringByAbbreviatingWithTildeInPath:aURL];
}

- (id<ViDeferred>)attributesOfItemAtURL:(NSURL *)aURL
			   onCompletion:(void (^)(NSURL *, NSDictionary *, NSError *))aBlock
{
	DEBUG(@"url = %@", aURL);

	return [[SFTPConnectionPool sharedPool] connectionWithURL:aURL onConnect:^(SFTPConnection *conn, NSError *error) {
		if (!error)
			return [conn attributesOfItemAtURL:aURL onResponse:aBlock];
		aBlock(nil, nil, error);
		return nil;
	}];
}

- (id<ViDeferred>)fileExistsAtURL:(NSURL *)aURL
		     onCompletion:(void (^)(NSURL *, BOOL, NSError *))aBlock
{
	DEBUG(@"url = %@", aURL);

	return [[SFTPConnectionPool sharedPool] connectionWithURL:aURL onConnect:^(SFTPConnection *conn, NSError *error) {
		if (!error)
			return [conn fileExistsAtURL:aURL onResponse:aBlock];
		aBlock(nil, NO, error);
		return nil;
	}];
}

- (id<ViDeferred>)contentsOfDirectoryAtURL:(NSURL *)aURL
			      onCompletion:(void (^)(NSArray *contents, NSError *error))aBlock
{
	DEBUG(@"url = %@", aURL);

	return [[SFTPConnectionPool sharedPool] connectionWithURL:aURL onConnect:^(SFTPConnection *conn, NSError *error) {
		if (!error)
			return [conn contentsOfDirectoryAtURL:aURL onResponse:aBlock];
		aBlock(nil, error);
		return nil;
	}];
}

- (id<ViDeferred>)createDirectoryAtURL:(NSURL *)aURL
			  onCompletion:(void (^)(NSError *error))aBlock
{
	DEBUG(@"url = %@", aURL);

	return [[SFTPConnectionPool sharedPool] connectionWithURL:aURL onConnect:^(SFTPConnection *conn, NSError *error) {
		if (!error)
			return [conn createDirectory:[aURL path] onResponse:aBlock];
		aBlock(error);
		return nil;
	}];
}

- (id<ViDeferred>)moveItemAtURL:(NSURL *)srcURL
			  toURL:(NSURL *)dstURL
		   onCompletion:(void (^)(NSURL *, NSError *error))aBlock
{
	DEBUG(@"%@ -> %@", srcURL, dstURL);

	return [[SFTPConnectionPool sharedPool] connectionWithURL:srcURL
							onConnect:^(SFTPConnection *conn, NSError *error) {
		if (!error)
			return [conn moveItemAtURL:srcURL
					     toURL:dstURL
					onResponse:aBlock];
		aBlock(nil, error);
		return nil;
	}];
}

- (id<ViDeferred>)removeItemAtURL:(NSURL *)aURL
		     onCompletion:(void (^)(NSError *))aBlock
{
	DEBUG(@"url = %@", aURL);

	return [[SFTPConnectionPool sharedPool] connectionWithURL:aURL
							onConnect:^(SFTPConnection *conn, NSError *error) {
		if (!error)
			return [conn removeItemAtPath:[aURL path] onResponse:aBlock];
		aBlock(error);
		return nil;
	}];
}

- (id<ViDeferred>)removeItemsAtURLs:(NSArray *)urls
		       onCompletion:(void (^)(NSError *))aBlock
{
	return [[SFTPConnectionPool sharedPool] connectionWithURL:[urls objectAtIndex:0]
							onConnect:^(SFTPConnection *conn, NSError *error) {
		if (!error)
			return [conn removeItemsAtURLs:urls onResponse:aBlock];
		aBlock(error);
		return nil;
	}];
}

- (id<ViDeferred>)dataWithContentsOfURL:(NSURL *)aURL
				 onData:(void (^)(NSData *))dataCallback
			   onCompletion:(void (^)(NSURL *, NSDictionary *, NSError *))completionCallback
{
	DEBUG(@"url = %@", aURL);

	return [[SFTPConnectionPool sharedPool] connectionWithURL:aURL
							onConnect:^(SFTPConnection *conn, NSError *error) {
		if (!error)
			return [conn dataWithContentsOfURL:aURL
						    onData:dataCallback
						onResponse:completionCallback];
		completionCallback(nil, nil, error);
		return nil;
	}];
}

- (id<ViDeferred>)writeDataSafely:(NSData *)data
			    toURL:(NSURL *)aURL
		     onCompletion:(void (^)(NSURL *, NSDictionary *, NSError *))aBlock
{
	DEBUG(@"url = %@", aURL);

	return [[SFTPConnectionPool sharedPool] connectionWithURL:aURL
							onConnect:^(SFTPConnection *conn, NSError *error) {
		if (!error)
			return [conn writeDataSafely:data toURL:aURL onResponse:aBlock];
		aBlock(nil, nil, error);
		return nil;
	}];
}

@end
