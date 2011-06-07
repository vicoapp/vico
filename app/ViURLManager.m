#import "ViURLManager.h"
#import "ViError.h"
#import "ViCommon.h"
#import "NSObject+SPInvocationGrabbing.h"

/* XXX: this is butt ugly! */
#import "ViWindowController.h"
#import "ProjectDelegate.h"

#include "logging.h"

@interface ViURLManager (private)
- (void)cacheContents:(NSArray *)contents forDirectoryAtURL:(NSURL *)aURL;
- (void)monitorDirectoryAtURL:(NSURL *)aURL;
- (void)restartEvents;
- (void)stopEvents;
@end

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

- (void)finalize
{
	[self stopEvents];
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
	[self restartEvents];
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
	DEBUG(@"flushing cache for %@", aURL);
	NSString *key = [[[self normalizeURL:aURL] absoluteString] stringByTrimmingCharactersInSet:slashSet];
	[directoryCache removeObjectForKey:key];
}

- (void)cacheContents:(NSArray *)contents forDirectoryAtURL:(NSURL *)aURL
{
	DEBUG(@"caching contents of URL %@", aURL);

	NSString *key = [[aURL absoluteString] stringByTrimmingCharactersInSet:slashSet];
	[directoryCache setObject:contents forKey:key];
	[[NSNotificationCenter defaultCenter] postNotificationName:ViURLContentsCachedNotification
							    object:self
							  userInfo:[NSDictionary dictionaryWithObject:aURL
											       forKey:@"URL"]];
	[self monitorDirectoryAtURL:aURL];
}

- (BOOL)shouldRescanDirectoryAtURL:(NSURL *)aURL
{
	// XXX: check if this URL is displayed by a project explorer
	for (NSWindow *window in [NSApp windows]) {
		ViWindowController *wincon = [window windowController];
		if ([wincon respondsToSelector:@selector(explorer)]) {
			ProjectDelegate *explorer = [wincon explorer];
			if ([explorer displaysURL:aURL])
				return YES;
		}
	}

	DEBUG(@"URL %@ not displayed by any project explorer", aURL);
	return NO;
}

/* Called by ourselves whenever we know a directory has changed, e.g. when
 * creating a new document.
 */
- (void)notifyChangedDirectoryAtURL:(NSURL *)aURL force:(BOOL)force
{
	DEBUG(@"directory %@ has changed", aURL);

	if (!force && [aURL isFileURL]) {
		/* FS events does a better job for local files. */
		return;
	}

	if (![self directoryIsCachedAtURL:aURL])
		return;

	[self flushCachedContentsOfDirectoryAtURL:aURL];

	if ([self shouldRescanDirectoryAtURL:aURL]) {
		[self contentsOfDirectoryAtURL:aURL onCompletion:^(NSArray *contents, NSError *error) {
			/* Any interested project explorer will get a notification. */
			DEBUG(@"rescanned URL %@, error %@", aURL, error);
		}];
	} else if ([aURL isFileURL])
		[self restartEvents];
}

- (void)notifyChangedDirectoryAtURL:(NSURL *)aURL
{
	[self notifyChangedDirectoryAtURL:aURL force:NO];
}

#pragma mark -
#pragma mark File System Events

- (void)stopEvents
{
	if (evstream) {
		DEBUG(@"stopping fs events %@", FSEventStreamCopyDescription(evstream));
		FSEventStreamStop(evstream);
		FSEventStreamUnscheduleFromRunLoop(evstream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
		FSEventStreamInvalidate(evstream);
		FSEventStreamRelease(evstream);
		evstream = NULL;
	}
}

void mycallback(
    ConstFSEventStreamRef streamRef,
    void *clientCallBackInfo,
    size_t numEvents,
    void *eventPaths,
    const FSEventStreamEventFlags eventFlags[],
    const FSEventStreamEventId eventIds[])
{
	int i;
	char **paths = eventPaths;
	ViURLManager *urlManager = clientCallBackInfo;

	for (i = 0; i < numEvents; i++) {
		NSString *path = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:paths[i]
											     length:strlen(paths[i])];
		NSURL *url = [NSURL fileURLWithPath:path];
		[[urlManager nextRunloop] notifyChangedDirectoryAtURL:url force:YES];
	}
}

- (BOOL)URLIsMonitored:(NSURL *)aURL
{
	if (evstream == NULL)
		return NO;

	NSString *path = [aURL path];
	NSArray *pathsBeingWatched = (NSArray *)FSEventStreamCopyPathsBeingWatched(evstream);
	for (NSString *p in pathsBeingWatched)
		if ([path hasPrefix:p]) {
			DEBUG(@"URL %@ is already being watched", aURL);
			return YES;
		}

	return NO;
}

- (NSArray *)pathsToWatch
{
	NSMutableArray *paths = [NSMutableArray array];
	NSArray *keys = [[directoryCache allKeys] sortedArrayUsingSelector:@selector(compare:)];
	for (NSUInteger i = 0; i < [keys count]; i++) {
		NSString *key = [keys objectAtIndex:i];
		if (i > 0 && [key hasPrefix:[keys objectAtIndex:i - 1]]) {
			DEBUG(@"%@ is a child of %@", key, [keys objectAtIndex:i - 1]);
			continue;
		}

		NSURL *url = [NSURL URLWithString:key];
		if ([url isFileURL])
			[paths addObject:[url path]];
	}

	DEBUG(@"paths = %@", paths);
	return paths;
}

- (void)restartEvents
{
	[self stopEvents];

	NSArray *paths = [self pathsToWatch];
	if ([paths count] == 0)
		return;

	CFAbsoluteTime latency = 0.3; /* Latency in seconds */

	struct FSEventStreamContext ctx;
	bzero(&ctx, sizeof(ctx));
	ctx.info = self;

	evstream = FSEventStreamCreate(NULL,
		&mycallback,
		&ctx,
		(CFArrayRef)paths,
		kFSEventStreamEventIdSinceNow,
		latency,
		kFSEventStreamCreateFlagWatchRoot
	);

	FSEventStreamScheduleWithRunLoop(evstream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	FSEventStreamStart(evstream);
}

- (void)monitorDirectoryAtURL:(NSURL *)aURL
{
	if ([aURL isFileURL] && ![self URLIsMonitored:aURL])
		[self restartEvents];
}

@end
