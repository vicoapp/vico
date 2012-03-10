#import "ViURLManager.h"
#import "ViError.h"
#import "ViCommon.h"
#import "NSObject+SPInvocationGrabbing.h"
#import "ViEventManager.h"
#include "logging.h"

/* XXX: this is butt ugly! */
#import "ViWindowController.h"
#import "ViFileExplorer.h"

@implementation ViURLManager

+ (ViURLManager *)defaultManager
{
	static id __defaultManager = nil;
	if (__defaultManager == nil) {
		__defaultManager = [[ViURLManager alloc] init];
	}
	return __defaultManager;
}

- (ViURLManager *)init
{
	if ((self = [super init]) != nil) {
		_handlers = [[NSMutableArray alloc] init];
		_directoryCache = [[NSMutableDictionary alloc] init];
		_slashSet = [[NSCharacterSet characterSetWithCharactersInString:@"/"] retain];
		_lastEventId = kFSEventStreamEventIdSinceNow;
	}

	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	[self stopEvents];
	[_handlers release];
	[_directoryCache release];
	[_slashSet release];
	[super dealloc];
}

- (void)finalize
{
	[self stopEvents];
	[super finalize];
}

- (void)registerHandler:(id<ViURLHandler>)handler
{
	[_handlers addObject:handler];
}

- (id<ViURLHandler>)handlerForURL:(NSURL *)aURL
{
	id<ViURLHandler> handler;
	for (handler in _handlers)
		if ([handler respondsToURL:aURL])
			return handler;

	DEBUG(@"no handler found for URL %@", aURL);
	return nil;
}

- (id<ViURLHandler>)handlerForURL:(NSURL *)aURL
			 selector:(SEL)aSelector
{
	id<ViURLHandler> handler;
	for (handler in _handlers) {
		if ([handler respondsToSelector:aSelector] &&
		    [handler respondsToURL:aURL]) {
			return handler;
		}
	}

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

- (NSString *)stringByAbbreviatingWithTildeInPath:(NSURL *)aURL
{
	id<ViURLHandler> handler = [self handlerForURL:aURL selector:@selector(stringByAbbreviatingWithTildeInPath:)];
	if (handler)
		return [handler stringByAbbreviatingWithTildeInPath:aURL];
	return [aURL absoluteString];
}

- (id<ViDeferred>)contentsOfDirectoryAtURL:(NSURL *)aURL
			      onCompletion:(void (^)(NSArray *, NSError *))completionCallback
{
	id<ViURLHandler> handler = [self handlerForURL:aURL
					      selector:@selector(contentsOfDirectoryAtURL:onCompletion:)];
	if (handler) {
		NSURL *normalizedURL = [self normalizeURL:aURL];
		NSArray *cachedContents = [self cachedContentsOfDirectoryAtURL:aURL];
		if (cachedContents) {
			completionCallback(cachedContents, nil);
			return nil;
		}

		DEBUG(@"reading contents of %@", normalizedURL);
                /*
                 * The completionCallback argument is typically a stack
                 * block literal and can't be automatically retained
                 * without moving it to the heap.
		 */
		void (^completionCallbackCopy)(NSArray *, NSError *) = [[completionCallback copy] autorelease];
		return [handler contentsOfDirectoryAtURL:normalizedURL
					    onCompletion:^(NSArray *contents, NSError *error) {
			if (contents && !error)
				[self cacheContents:contents forDirectoryAtURL:normalizedURL];
			completionCallbackCopy(contents, error);
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
		   onCompletion:(void (^)(NSURL *, NSError *))aBlock
{
	if (![[srcURL scheme] isEqualToString:[dstURL scheme]]) {
		aBlock(nil, [ViError errorWithFormat:@"Moving between different URL schemes not supported (%@ => %@)",
		    [srcURL scheme], [dstURL scheme]]);
		return nil;
	}

	id<ViURLHandler> handler = [self handlerForURL:dstURL
					      selector:@selector(moveItemAtURL:toURL:onCompletion:)];
	if (handler)
		return [handler moveItemAtURL:srcURL toURL:dstURL onCompletion:aBlock];
	aBlock(nil, [ViError errorWithFormat:@"Unsupported URL scheme %@", [dstURL scheme]]);
	return nil;
}

/* All URLs must be of the same type (scheme). */
- (id<ViDeferred>)removeItemsAtURLs:(NSArray *)urls
		       onCompletion:(void (^)(NSError *))aBlock
{
	NSURL *firstURL = nil;
	if ([urls count] > 0)
		firstURL = [urls objectAtIndex:0];
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
	[_directoryCache removeAllObjects];
	[self restartEvents];
}

- (NSArray *)cachedContentsOfDirectoryAtURL:(NSURL *)aURL
{
	NSString *key = [[[self normalizeURL:aURL] absoluteString] stringByTrimmingCharactersInSet:_slashSet];
	return [_directoryCache objectForKey:key];
}

- (BOOL)directoryIsCachedAtURL:(NSURL *)aURL
{
	return [self cachedContentsOfDirectoryAtURL:aURL] != nil;
}

- (void)flushCachedContentsOfDirectoryAtURL:(NSURL *)aURL
{
	DEBUG(@"flushing cache for %@", aURL);
	NSString *key = [[[self normalizeURL:aURL] absoluteString] stringByTrimmingCharactersInSet:_slashSet];
	[_directoryCache removeObjectForKey:key];
}

- (void)cacheContents:(NSArray *)contents forDirectoryAtURL:(NSURL *)aURL
{
	DEBUG(@"caching contents of URL %@", aURL);

	NSString *key = [[[self normalizeURL:aURL] absoluteString] stringByTrimmingCharactersInSet:_slashSet];
	[_directoryCache setObject:contents forKey:key];
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
			ViFileExplorer *explorer = [wincon explorer];
			if ([explorer displaysURL:aURL]) {
				return YES;
			}
		}
	}

	DEBUG(@"URL %@ not displayed by any project explorer", aURL);
	return NO;
}

/* Called by ourselves whenever we know a directory has changed, e.g. when
 * creating a new document.
 */
- (void)notifyChangedDirectoryAtURL:(NSURL *)aURL
			recursively:(BOOL)recursiveFlush
			      force:(BOOL)force
{
	if (!force && [aURL isFileURL]) {
		/* FS events does a better job for local files. */
		return;
	}

	DEBUG(@"directory %@ has changed, recursive = %s", aURL, recursiveFlush ? "YES" : "NO");

	// XXX: Why is this event not triggered by the file explorer itself!?
	[[ViEventManager defaultManager] emit:ViEventDirectoryChanged for:nil with:aURL, nil];
	for (NSWindow *window in [NSApp windows]) {
		ViWindowController *wincon = [window windowController];
		if ([wincon respondsToSelector:@selector(explorer)]) {
			ViFileExplorer *explorer = [wincon explorer];
			if ([explorer displaysURL:aURL])
				[[ViEventManager defaultManager] emit:ViEventExplorerDirectoryChanged
								  for:explorer
								 with:explorer, aURL, nil];
		}
	}

	if (!recursiveFlush) {
		if (![self directoryIsCachedAtURL:aURL]) {
			return;
		}
		[self flushCachedContentsOfDirectoryAtURL:aURL];
		if ([self shouldRescanDirectoryAtURL:aURL]) {
			[self contentsOfDirectoryAtURL:aURL onCompletion:^(NSArray *contents, NSError *error) {
				/* Any interested project explorer will get a notification. */
				DEBUG(@"rescanned URL %@, error %@", aURL, error);
			}];
		} else if ([aURL isFileURL]) {
			[self restartEvents]; /* To un-monitor the flushed directory. */
		}
		return;
	}

	/* Recursively flush all descendant URLs.
	 */
	NSString *changedKey = [[[self normalizeURL:aURL] absoluteString] stringByTrimmingCharactersInSet:_slashSet];
	BOOL restart = NO;
	NSArray *keys = [[_directoryCache allKeys] sortedArrayUsingSelector:@selector(compare:)];
	for (NSUInteger i = 0; i < [keys count]; i++) {
		NSString *key = [keys objectAtIndex:i];
		if ([key hasPrefix:changedKey]) {
			NSURL *url = [NSURL URLWithString:[key stringByAppendingString:@"/"]];
			[self flushCachedContentsOfDirectoryAtURL:url];

			if ([self shouldRescanDirectoryAtURL:url]) {
				[self contentsOfDirectoryAtURL:url onCompletion:^(NSArray *contents, NSError *error) {
					/* Any interested project explorer will get a notification. */
					DEBUG(@"rescanned URL %@, error %@", url, error);
				}];
			} else {
				restart = YES;
			}
		}
	}

	if (restart && [aURL isFileURL]) {
		[self restartEvents];
	}
}

- (void)notifyChangedDirectoryAtURL:(NSURL *)aURL
{
	[self notifyChangedDirectoryAtURL:aURL recursively:NO force:NO];
}

#pragma mark -
#pragma mark File System Events

- (void)stopEvents
{
	if (_evstream) {
		DEBUG(@"stopping fs events %@", FSEventStreamCopyDescription(_evstream));
		_lastEventId = FSEventStreamGetLatestEventId(_evstream);
		FSEventStreamStop(_evstream);
		FSEventStreamUnscheduleFromRunLoop(_evstream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
		FSEventStreamInvalidate(_evstream);
		FSEventStreamRelease(_evstream);
		_evstream = NULL;
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
		NSUInteger flags = eventFlags[i];
		DEBUG(@"URL %@ changed w/flags 0x%04x", url, eventFlags[i]);
		[[urlManager nextRunloop] notifyChangedDirectoryAtURL:url
							  recursively:(flags & kFSEventStreamEventFlagMustScanSubDirs)
								force:YES];
	}
}

- (BOOL)URLIsMonitored:(NSURL *)aURL
{
	if (_evstream == NULL)
		return NO;

	NSString *path = [aURL path];
	NSArray *pathsBeingWatched = (NSArray *)FSEventStreamCopyPathsBeingWatched(_evstream);
	for (NSString *p in pathsBeingWatched) {
		if ([path hasPrefix:p]) {
			DEBUG(@"URL %@ is already being watched", aURL);
			CFRelease(pathsBeingWatched);
			return YES;
		}
	}

	CFRelease(pathsBeingWatched);
	return NO;
}

- (NSArray *)pathsToWatch
{
	NSMutableArray *paths = [NSMutableArray array];
	NSArray *keys = [[_directoryCache allKeys] sortedArrayUsingSelector:@selector(compare:)];
	NSString *lastKey = nil;
	for (NSUInteger i = 0; i < [keys count]; i++) {
		NSString *key = [keys objectAtIndex:i];
		if (lastKey && [key hasPrefix:lastKey]) {
			DEBUG(@"%@ is a child of %@", key, lastKey);
			continue;
		}

		lastKey = key;
		NSURL *url = [NSURL URLWithString:[key stringByAppendingString:@"/"]];
		if ([url isFileURL]) {
			NSError *error = nil;
			if ([url checkResourceIsReachableAndReturnError:&error])
				[paths addObject:[url path]];
			else {
				INFO(@"url %@ is not reachable: %@", url, [error localizedDescription]);
				[self flushCachedContentsOfDirectoryAtURL:url];
			}
		}
	}

	DEBUG(@"paths = %@", paths);
	return paths;
}

- (void)restartEvents
{
	[self stopEvents];

	NSArray *paths = [self pathsToWatch];
	if ([paths count] == 0) {
		DEBUG(@"%s", "nothing to monitor");
		return;
	}

	CFAbsoluteTime latency = 0.3; /* Latency in seconds */

	struct FSEventStreamContext ctx;
	bzero(&ctx, sizeof(ctx));
	ctx.info = self;

	DEBUG(@"listening for events since %lu", _lastEventId);
	_evstream = FSEventStreamCreate(NULL,
		&mycallback,
		&ctx,
		(CFArrayRef)paths,
		_lastEventId,
		latency,
		kFSEventStreamCreateFlagWatchRoot
	);

	if (_evstream != NULL) {
		FSEventStreamScheduleWithRunLoop(_evstream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
		FSEventStreamStart(_evstream);
	}
}

- (void)monitorDirectoryAtURL:(NSURL *)aURL
{
	if ([aURL isFileURL] && ![self URLIsMonitored:aURL])
		[self restartEvents];
}

@end
