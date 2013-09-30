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

#import "SFTPConnectionPool.h"
#import "ViError.h"
#include "logging.h"

@implementation SFTPConnectionPool

- (SFTPConnectionPool *)init
{
	if ((self = [super init]) != nil) {
		_connections = [[NSMutableDictionary alloc] init];
	}
	return self;
}


+ (SFTPConnectionPool *)sharedPool
{
	static SFTPConnectionPool *__sharedPool = nil;
	if (__sharedPool == nil)
		__sharedPool = [[SFTPConnectionPool alloc] init];
	return __sharedPool;
}

- (NSString *)connectionKeyForURL:(NSURL *)aURL
{
	NSString *username = [aURL user];
	NSString *hostname = [aURL host];
	NSNumber *port = [aURL port];
	return [NSString stringWithFormat:@"%@@%@:%@", username ?: @"", hostname, port ?: @"22"];
}

- (NSURL *)normalizeURL:(NSURL *)aURL
{
	NSString *key = [self connectionKeyForURL:aURL];
	SFTPConnection *conn = [_connections objectForKey:key];
	if (conn && [conn connected])
		return [conn normalizeURL:aURL];
	return aURL;
}

- (NSString *)stringByAbbreviatingWithTildeInPath:(NSURL *)aURL
{
	NSString *key = [self connectionKeyForURL:aURL];
	SFTPConnection *conn = [_connections objectForKey:key];
	if (conn && [conn connected])
		return [conn stringByAbbreviatingWithTildeInPath:aURL];
	return [aURL absoluteString];
}

- (id<ViDeferred>)connectionWithURL:(NSURL *)url
			  onConnect:(SFTPRequest *(^)(SFTPConnection *, NSError *))connectCallback
{
	if ([url host] == nil)
		return connectCallback(nil,
		    [ViError errorWithFormat:@"missing hostname in URL %@", url]);

	NSString *key = [self connectionKeyForURL:url];
	SFTPConnection *conn = [_connections objectForKey:key];

	if (conn && [conn closed]) {
		DEBUG(@"connection %@ is closed", conn);
		[_connections removeObjectForKey:key];
		conn = nil;
	}

	if (conn == nil) {
		NSError *error = nil;
		conn = [[SFTPConnection alloc] initWithURL:url error:&error];
		if (conn == nil || error)
			return connectCallback(nil, error);

		[_connections setObject:conn forKey:key];

		__weak SFTPRequest *initRequest = nil;
		void (^initCallback)(NSError *) = ^(NSError *error) {
			initRequest.subRequest = connectCallback(conn, error);
		};
		initRequest = [conn onConnect:initCallback];
		return initRequest;
	} else
		return connectCallback(conn, nil);

	return nil;
}

@end

