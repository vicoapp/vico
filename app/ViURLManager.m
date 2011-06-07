#import "ViURLManager.h"
#import "ViError.h"
#import "ViCommon.h"
#include "logging.h"

@implementation ViURLManager

+ (ViURLManager *)defaultManager
{
	static id defaultManager = nil;
	if (defaultManager == nil) {
		defaultManager = [[ViURLManager alloc] init];
	}
	return defaultManager;
}

- (ViURLManager *)init
{
	if ((self = [super init]) != nil) {
		handlers = [NSMutableArray array];
		directoryCache = [NSMutableDictionary dictionary];
		slashSet = [NSCharacterSet characterSetWithCharactersInString:@"/"];
	}

	return self;
}

- (void)registerHandler:(id<ViURLHandler>)handler
{
	[handlers addObject:handler];
}

- (id<ViURLHandler>)handlerForURL:(NSURL *)aURL
{
	id<ViURLHandler> handler;
	for (handler in handlers)
		if ([handler respondsToURL:aURL])
			return handler;

	DEBUG(@"no handler found for URL %@", aURL);
	return nil;
}

- (id<ViURLHandler>)handlerForURL:(NSURL *)aURL
			 selector:(SEL)aSelector
{
	id<ViURLHandler> handler;
	for (handler in handlers)
		if ([handler respondsToSelector:aSelector] &&
		    [handler respondsToURL:aURL])
			return handler;

	DEBUG(@"no handler found for URL %@ and selector %@",
	    aURL, NSStringFromSelector(aSelector));
	return nil;
}

- (BOOL)respondsToURL:(NSURL *)aURL
{
	return [self handlerForURL:aURL] != nil;
}

- (NSURL *)normalizeURL:(NSURL *)aURL
{
	id<ViURLHandler> handler = [self handlerForURL:aURL selector:@selector(normalizeURL:)];
	if (handler)
		return [handler normalizeURL:aURL];
	return aURL;
}

- (id<ViDeferred>)contentsOfDirectoryAtURL:(NSURL *)aURL
			      onCompletion:(void (^)(NSArray *, NSError *))completionCallback
{
	id<ViURLHandler> handler = [self handlerForURL:aURL
					      selector:@selector(contentsOfDirectoryAtURL:onCompletion:)];
	if (handler) {
		NSURL *normalizedURL = [self normalizeURL:aURL];
		NSArray *contents = [self cachedContentsOfDirectoryAtURL:aURL];
		if (contents) {
			completionCallback(contents, nil);
			return nil;
		}

		DEBUG(@"reading contents of %@", normalizedURL);
		return [handler contentsOfDirectoryAtURL:normalizedURL onCompletion:^(NSArray *contents, NSError *error) {
			if (contents && !error)
				[self cacheContents:contents forDirectoryAtURL:normalizedURL];
			completionCallback(contents, error);
		}];
	}

	completionCallback(nil, [ViError errorWithFormat:@"Unsupported URL scheme %@", [aURL scheme]]);
	return nil;
}

- (id<ViDeferred>)createDirectoryAtURL:(NSURL *)aURL
			  onCompletion:(void (^)(NSError *))aBlock
{
	id<ViURLHandler> handler = [self handlerForURL:aURL
					      selector:@selector(createDirectoryAtURL:onCompletion:)];
	if (handler)
		return [handler createDirectoryAtURL:aURL onCompletion:aBlock];
	aBlock([ViError errorWithFormat:@"Unsupported URL scheme %@", [aURL scheme]]);
	return nil;
}

- (id<ViDeferred>)fileExistsAtURL:(NSURL *)aURL
		     onCompletion:(void (^)(NSURL *, BOOL, NSError *))aBlock
{
	id<ViURLHandler> handler = [self handlerForURL:aURL
					      selector:@selector(fileExistsAtURL:onCompletion:)];
	if (handler)
		return [handler fileExistsAtURL:aURL onCompletion:aBlock];
	aBlock(nil, NO, [ViError errorWithFormat:@"Unsupported URL scheme %@", [aURL scheme]]);
	return nil;
}

- (id<ViDeferred>)moveItemAtURL:(NSURL *)srcURL
			  toURL:(NSURL *)dstURL
		   onCompletion:(void (^)(NSError *))aBlock
{
	if (![[srcURL scheme] isEqualToString:[dstURL scheme]]) {
		aBlock([ViError errorWithFormat:@"Moving between different URL schemes not implemented (%@ => %@)",
		    [srcURL scheme], [dstURL scheme]]);
		return nil;
	}

	id<ViURLHandler> handler = [self handlerForURL:dstURL
					      selector:@selector(moveItemAtURL:toURL:onCompletion:)];
	if (handler)
		return [handler moveItemAtURL:srcURL toURL:dstURL onCompletion:aBlock];
	aBlock([ViError errorWithFormat:@"Unsupported URL scheme %@", [dstURL scheme]]);
	return nil;
}

/* All URLs must be of the same type (scheme). */
- (id<ViDeferred>)removeItemsAtURLs:(NSArray *)urls
		       onCompletion:(void (^)(NSError *))aBlock
{
	NSURL *firstURL = [urls objectAtIndex:0];
	if (firstURL == nil) {
		aBlock(nil);
		return nil;
	}

	id<ViURLHandler> handler = [self handlerForURL:firstURL
					      selector:@selector(removeItemsAtURLs:onCompletion:)];
	if (handler)
		return [handler removeItemsAtURLs:urls onCompletion:aBlock];

	aBlock([ViError errorWithFormat:@"Unsupported URL scheme %@", [firstURL scheme]]);
	return nil;
}

- (id<ViDeferred>)removeItemAtURL:(NSURL *)aURL
		     onCompletion:(void (^)(NSError *))aBlock
{
	id<ViURLHandler> handler = [self handlerForURL:aURL
					      selector:@selector(removeItemAtURL:onCompletion:)];
	if (handler)
		return [handler removeItemAtURL:aURL onCompletion:aBlock];
	aBlock([ViError errorWithFormat:@"Unsupported URL scheme %@", [aURL scheme]]);
	return nil;
}

- (id<ViDeferred>)attributesOfItemAtURL:(NSURL *)aURL
			   onCompletion:(void (^)(NSURL *, NSDictionary *, NSError *))aBlock
{
	id<ViURLHandler> handler = [self handlerForURL:aURL
					      selector:@selector(attributesOfItemAtURL:onCompletion:)];
	if (handler)
		return [handler attributesOfItemAtURL:aURL onCompletion:aBlock];
	aBlock(nil, nil, [ViError errorWithFormat:@"Unsupported URL scheme %@", [aURL scheme]]);
	return nil;
}

- (id<ViDeferred>)dataWithContentsOfURL:(NSURL *)aURL
				 onData:(void (^)(NSData *))dataCallback
			   onCompletion:(void (^)(NSURL *, NSDictionary *, NSError *))completionCallback
{
	id<ViURLHandler> handler = [self handlerForURL:aURL
					      selector:@selector(dataWithContentsOfURL:onData:onCompletion:)];
	if (handler)
		return [handler dataWithContentsOfURL:aURL
					       onData:dataCallback
					 onCompletion:completionCallback];
	completionCallback(nil, nil, [ViError errorWithFormat:@"Unsupported URL scheme %@", [aURL scheme]]);
	return nil;
}

- (id<ViDeferred>)writeDataSafely:(NSData *)data
			    toURL:(NSURL *)aURL
		     onCompletion:(void (^)(NSURL *, NSDictionary *, NSError *))aBlock
{
	id<ViURLHandler> handler = [self handlerForURL:aURL
					      selector:@selector(writeDataSafely:toURL:onCompletion:)];
	if (handler)
		return [handler writeDataSafely:data toURL:aURL onCompletion:aBlock];
	aBlock(nil, nil, [ViError errorWithFormat:@"Unsupported URL scheme %@", [aURL scheme]]);
	return nil;
}

#pragma mark -
#pragma mark Directory Cache Control

- (void)flushDirectoryCache
{
	directoryCache = [NSMutableDictionary dictionary];
}

- (NSArray *)cachedContentsOfDirectoryAtURL:(NSURL *)aURL
{
	NSString *key = [[[self normalizeURL:aURL] absoluteString] stringByTrimmingCharactersInSet:slashSet];
	return [directoryCache objectForKey:key];
}

- (BOOL)directoryIsCachedAtURL:(NSURL *)aURL
{
	return [self cachedContentsOfDirectoryAtURL:aURL] != nil;
}

- (void)flushCachedContentsOfDirectoryAtURL:(NSURL *)aURL
{
	NSString *key = [[[self normalizeURL:aURL] absoluteString] stringByTrimmingCharactersInSet:slashSet];
	[directoryCache removeObjectForKey:key];
}

- (void)cacheContents:(NSArray *)contents forDirectoryAtURL:(NSURL *)aURL
{
	NSString *key = [[aURL absoluteString] stringByTrimmingCharactersInSet:slashSet];
	[directoryCache setObject:contents forKey:key];
	[[NSNotificationCenter defaultCenter] postNotificationName:ViURLContentsCachedNotification
							    object:self
							  userInfo:[NSDictionary dictionaryWithObject:aURL
											       forKey:@"URL"]];
}

- (BOOL)shouldRescanDirectoryAtURL:(NSURL *)aURL
{
	if (![self directoryIsCachedAtURL:aURL])
		return NO;
	// FIXME: check if this URL is displayed by a project explorer
	return YES;
}

/* Called by ourselves whenever we know a directory has changed, e.g. when
 * creating a new document.
 */
- (void)notifyChangedDirectoryAtURL:(NSURL *)aURL
{
	if ([aURL isFileURL]) {
		/* FS events does a better job for local files. */
		return;
	}

	if ([self shouldRescanDirectoryAtURL:aURL]) {
		[self flushCachedContentsOfDirectoryAtURL:aURL];
		[self contentsOfDirectoryAtURL:aURL onCompletion:^(NSArray *contents, NSError *error) {
			/* Any interested project explorer will get a notification. */
			DEBUG(@"rescanned URL %@, error %@", aURL, error);
		}];
	}
}

@end
