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
