#import "ViFileURLHandler.h"
#import "ViError.h"
#include "logging.h"

@interface ViFileDeferred : NSObject <ViDeferred>
{
	id<ViDeferredDelegate> delegate;
}
@end

@implementation ViFileDeferred
@synthesize delegate;
+ (ViFileDeferred *)sharedDeferred
{
	static ViFileDeferred *sharedDeferred = nil;
	if (sharedDeferred == nil)
		sharedDeferred = [[ViFileDeferred alloc] init];
	return sharedDeferred;
}
- (void)cancel
{
}
- (void)wait
{
}
@end

@implementation ViFileURLHandler

- (id)init
{
	if ((self = [super init]) != nil) {
		fm = [[NSFileManager alloc] init];
	}

	return self;
}

- (BOOL)respondsToURL:(NSURL *)aURL
{
	return [aURL isFileURL];
}

- (id<ViDeferred>)contentsOfDirectoryAtURL:(NSURL *)aURL
			      onCompletion:(void (^)(NSArray *contents, NSError *error))aBlock
{
	DEBUG(@"url = %@", aURL);

	if (aURL == nil) {
		aBlock(nil, [ViError errorWithFormat:@"Invalid argument."]);
		return nil;
	}

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
		NSFileManager *fileman = [[NSFileManager alloc] init];
		NSError *error = nil;
		NSArray *files = [fileman contentsOfDirectoryAtPath:[aURL path] error:&error];
		NSMutableArray *contents = [NSMutableArray array];
		for (NSString *filename in files) {
			NSDictionary *attrs;
			NSURL *u = [aURL URLByAppendingPathComponent:filename];
			NSString *p = [u path];
			attrs = [fileman attributesOfItemAtPath:p error:&error];
			if (attrs)
				[contents addObject:[NSArray arrayWithObjects:filename, attrs, nil]];
			else if (error)
				break;
		}

		/* Schedule completion block on main queue. */
		dispatch_sync(dispatch_get_main_queue(), ^{
			aBlock(contents, error);
		});
	});

	return [ViFileDeferred sharedDeferred];
}

- (id<ViDeferred>)createDirectoryAtURL:(NSURL *)aURL
			  onCompletion:(void (^)(NSError *error))aBlock
{
	DEBUG(@"url = %@", aURL);
	NSError *error = nil;
	[fm createDirectoryAtPath:[aURL path]
      withIntermediateDirectories:YES
		       attributes:nil
			    error:&error];
	aBlock(error);
	return nil;
}

- (NSURL *)normalizeURL:(NSURL *)aURL
{
	NSString *path = [aURL relativePath];
	if ([path length] == 0)
		path = NSHomeDirectory();
	else if ([path hasPrefix:@"~"])
		path = [NSHomeDirectory() stringByAppendingPathComponent:[path substringFromIndex:1]];
	else if ([path hasPrefix:@"/~"])
		path = [NSHomeDirectory() stringByAppendingPathComponent:[path substringFromIndex:2]];
	else
		return [[aURL URLByStandardizingPath] absoluteURL];
	return [[[NSURL fileURLWithPath:path] URLByStandardizingPath] absoluteURL];
}

- (id<ViDeferred>)attributesOfItemAtURL:(NSURL *)aURL
			   onCompletion:(void (^)(NSURL *, NSDictionary *, NSError *))aBlock
{
	DEBUG(@"url = %@", aURL);
	NSError *error = nil;
	NSURL *url = [self normalizeURL:aURL];
	NSDictionary *attributes = [fm attributesOfItemAtPath:[url path] error:&error];
	if (error || attributes == nil)
		aBlock(nil, nil, error);
	else
		aBlock(url, attributes, nil);
	return nil;
}

- (id<ViDeferred>)fileExistsAtURL:(NSURL *)aURL
		     onCompletion:(void (^)(NSURL *, BOOL, NSError *))aBlock
{
	DEBUG(@"url = %@", aURL);
	BOOL result, isDirectory;
	NSURL *url = [self normalizeURL:aURL];
	result = [fm fileExistsAtPath:[url path] isDirectory:&isDirectory];
	aBlock(result ? url : nil, isDirectory, nil);
	return nil;
}

- (id<ViDeferred>)moveItemAtURL:(NSURL *)srcURL
			  toURL:(NSURL *)dstURL
		   onCompletion:(void (^)(NSError *))aBlock
{
	DEBUG(@"%@ -> %@", srcURL, dstURL);
	NSError *error = nil;
	[fm moveItemAtURL:srcURL toURL:dstURL error:&error];
	aBlock(error);
	return nil;
}

- (id<ViDeferred>)removeItemsAtURLs:(NSArray *)urls
		       onCompletion:(void (^)(NSError *))aBlock
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	[workspace recycleURLs:urls completionHandler:^(NSDictionary *newURLs, NSError *error) {
		aBlock(error);
	}];
	return nil;
}

#if 0
- (id<ViDeferred>)dataWithContentsOfURL:(NSURL *)aURL
			   onCompletion:(void (^)(NSData *data, NSError *error))aBlock
{
	DEBUG(@"url = %@", aURL);
	NSError *error = nil;
	NSData *data;
	data = [NSData dataWithContentsOfFile:[aURL path]
				      options:0
					error:&error];
	aBlock(data, error);
	return nil;
}
#endif

- (id<ViDeferred>)writeDataSafely:(NSData *)data
			    toURL:(NSURL *)aURL
		     onCompletion:(void (^)(NSURL *, NSDictionary *, NSError *))aBlock
{
	DEBUG(@"url = %@", aURL);
	NSError *error = nil;
	[data writeToURL:aURL options:NSDataWritingAtomic error:&error];
	NSURL *normalizedURL = [self normalizeURL:aURL];
	NSDictionary *attributes = [fm attributesOfItemAtPath:[normalizedURL path] error:&error];
	aBlock(normalizedURL, attributes, error);
	return nil;
}

@end
