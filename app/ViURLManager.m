#import "ViURLManager.h"
#import "ViError.h"
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
	id<ViURLHandler> handler;
	for (handler in handlers)
		if ([handler respondsToURL:aURL])
			return [handler normalizeURL:aURL];
	return aURL;
}

- (void)flushDirectoryCache
{
	directoryCache = [NSMutableDictionary dictionary];
}

- (id<ViDeferred>)contentsOfDirectoryAtURL:(NSURL *)aURL
			      onCompletion:(void (^)(NSArray *, NSError *))aBlock
{
	id<ViURLHandler> handler = [self handlerForURL:aURL
					      selector:@selector(contentsOfDirectoryAtURL:onCompletion:)];
	if (handler) {
		NSURL *normalizedURL = [self normalizeURL:aURL];
		NSArray *contents = [directoryCache objectForKey:normalizedURL];
		if (contents) {
			aBlock(contents, nil);
			return nil;
		}

		return [handler contentsOfDirectoryAtURL:normalizedURL onCompletion:^(NSArray *contents, NSError *error) {
			if (contents && !error)
			       [directoryCache setObject:contents forKey:normalizedURL];
			aBlock(contents, error);
		}];
	}
	aBlock(nil, [ViError errorWithFormat:@"Unsupported URL scheme %@", [aURL scheme]]);
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

	/* Handle each URL one at a time. */
	handler = [self handlerForURL:firstURL selector:@selector(removeItemAtURL:onCompletion:)];
	if (handler) {
		NSMutableArray *mutableURLs = [urls mutableCopy];
		void (^fun)(void) = ^{
			NSURL *url = [mutableURLs objectAtIndex:0];
			[handler removeItemAtURL:url onCompletion:^(NSError *error) {
				[mutableURLs removeObjectAtIndex:0];
				if (error)
					aBlock(error);
				else if ([mutableURLs count] == 0)
					aBlock(nil);
				else
					fun();
			}];
		};
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), fun);
		return nil; // XXX: !!!
	}

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
		     onCompletion:(void (^)(NSError *))aBlock
{
	id<ViURLHandler> handler = [self handlerForURL:aURL
					      selector:@selector(writeDataSafely:toURL:onCompletion:)];
	if (handler)
		return [handler writeDataSafely:data toURL:aURL onCompletion:aBlock];
	aBlock([ViError errorWithFormat:@"Unsupported URL scheme %@", [aURL scheme]]);
	return nil;
}

@end
