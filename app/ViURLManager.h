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

@protocol ViDeferred;

@protocol ViDeferredDelegate <NSObject>
@optional
- (void)deferred:(id<ViDeferred>)deferred status:(NSString *)statusMessage;
@end



@protocol ViDeferred <NSObject>
@required
- (void)cancel;
- (void)wait;
@property(nonatomic,readwrite,assign) id<ViDeferredDelegate> delegate;

@optional
- (void)waitInWindow:(NSWindow *)window message:(NSString *)waitMessage;
- (CGFloat)progress;
@end



@protocol ViURLHandler <NSObject>
@required
- (BOOL)respondsToURL:(NSURL *)aURL;
- (NSURL *)normalizeURL:(NSURL *)aURL;

@optional
- (NSString *)stringByAbbreviatingWithTildeInPath:(NSURL *)aURL;
- (id<ViDeferred>)attributesOfItemAtURL:(NSURL *)aURL
			   onCompletion:(void (^)(NSURL *, NSDictionary *, NSError *))aBlock;
- (id<ViDeferred>)fileExistsAtURL:(NSURL *)aURL
		     onCompletion:(void (^)(NSURL *, BOOL, NSError *))aBlock;
- (id<ViDeferred>)dataWithContentsOfURL:(NSURL *)aURL
				 onData:(void (^)(NSData *))dataCallback
			   onCompletion:(void (^)(NSURL *, NSDictionary *, NSError *))completionCallback;

- (id<ViDeferred>)contentsOfDirectoryAtURL:(NSURL *)aURL onCompletion:(void (^)(NSArray *, NSError *))aBlock;
- (id<ViDeferred>)createDirectoryAtURL:(NSURL *)aURL onCompletion:(void (^)(NSError *))aBlock;
- (id<ViDeferred>)moveItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL onCompletion:(void (^)(NSURL *, NSError *))aBlock;
- (id<ViDeferred>)removeItemsAtURLs:(NSArray *)urls onCompletion:(void (^)(NSError *))aBlock;
- (id<ViDeferred>)writeDataSafely:(NSData *)data
			    toURL:(NSURL *)aURL
		     onCompletion:(void (^)(NSURL *, NSDictionary *, NSError *))aBlock;
- (id<ViDeferred>)removeItemAtURL:(NSURL *)aURL onCompletion:(void (^)(NSError *))aBlock;
@end



@interface ViURLManager : NSObject <ViURLHandler>
{
	NSMutableArray		*_handlers;
	NSMutableDictionary	*_directoryCache;
	NSCharacterSet		*_slashSet;

	// file system events
	FSEventStreamRef	 _evstream;
	FSEventStreamEventId	 _lastEventId;
}

+ (ViURLManager *)defaultManager;

- (void)registerHandler:(id<ViURLHandler>)handler;
- (void)flushDirectoryCache;
- (void)flushCachedContentsOfDirectoryAtURL:(NSURL *)aURL;
- (NSArray *)cachedContentsOfDirectoryAtURL:(NSURL *)aURL;
- (BOOL)directoryIsCachedAtURL:(NSURL *)aURL;
- (void)notifyChangedDirectoryAtURL:(NSURL *)aURL
			recursively:(BOOL)recursiveFlush
			      force:(BOOL)force;
- (void)notifyChangedDirectoryAtURL:(NSURL *)aURL;

- (void)cacheContents:(NSArray *)contents forDirectoryAtURL:(NSURL *)aURL;
- (void)monitorDirectoryAtURL:(NSURL *)aURL;
- (void)restartEvents;
- (void)stopEvents;

@end
