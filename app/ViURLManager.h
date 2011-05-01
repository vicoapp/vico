@protocol ViDeferred;

@protocol ViDeferredDelegate <NSObject>
@optional
- (void)deferred:(id<ViDeferred>)deferred status:(NSString *)statusMessage;
@end

@protocol ViDeferred <NSObject>
@required
- (void)cancel;
@property (readwrite, assign) id<ViDeferredDelegate> delegate;

@optional
- (CGFloat)progress;
@end

@protocol ViURLHandler <NSObject>
@required
- (BOOL)respondsToURL:(NSURL *)aURL;

@optional
- (id<ViDeferred>)dataWithContentsOfURL:(NSURL *)aURL
				 onData:(void (^)(NSData *data))dataCallback
			   onCompletion:(void (^)(NSError *error))completionCallback;
- (id<ViDeferred>)fileExistsAtURL:(NSURL *)aURL
		     onCompletion:(void (^)(BOOL result, BOOL isDirectory, NSError *error))aBlock;
- (id<ViDeferred>)contentsOfDirectoryAtURL:(NSURL *)aURL onCompletion:(void (^)(NSArray *contents, NSError *error))aBlock;
- (id<ViDeferred>)createDirectoryAtURL:(NSURL *)aURL onCompletion:(void (^)(NSError *error))aBlock;
- (id<ViDeferred>)moveItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL onCompletion:(void (^)(NSError *error))aBlock;
- (id<ViDeferred>)removeItemsAtURLs:(NSArray *)urls onCompletion:(void (^)(NSError *error))aBlock;
- (id<ViDeferred>)attributesOfItemAtURL:(NSURL *)aURL onCompletion:(void (^)(NSDictionary *attributes, NSError *error))aBlock;
- (id<ViDeferred>)writeDataSafely:(NSData *)data toURL:(NSURL *)aURL onCompletion:(void (^)(NSError *error))aBlock;
- (id<ViDeferred>)removeItemAtURL:(NSURL *)aURL onCompletion:(void (^)(NSError *error))aBlock;
@end

@interface ViURLManager : NSObject <ViURLHandler>
{
	NSMutableArray *handlers;
}
+ (ViURLManager *)defaultManager;
- (void)registerHandler:(id<ViURLHandler>)handler;
@end
