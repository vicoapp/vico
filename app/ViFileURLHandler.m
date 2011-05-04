#import "ViFileURLHandler.h"
#include "logging.h"

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
	NSError *error = nil;
	NSArray *files = [fm contentsOfDirectoryAtPath:[aURL path] error:&error];
	NSMutableArray *contents = [NSMutableArray array];
	for (NSString *filename in files) {
		NSDictionary *attrs;
		NSString *p = [[aURL path] stringByAppendingPathComponent:filename];
		attrs = [fm attributesOfItemAtPath:p error:&error];
		[contents addObject:[NSArray arrayWithObjects:filename, attrs, nil]];
	}

	aBlock(contents, error);
	return nil;
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
		return aURL;
	return [[NSURL fileURLWithPath:path] absoluteURL];
}

- (id<ViDeferred>)attributesOfItemAtURL:(NSURL *)aURL
			   onCompletion:(void (^)(NSURL *, NSDictionary *, NSError *))aBlock
{
	DEBUG(@"url = %@", aURL);
	NSError *error = nil;
	NSURL *url = [self normalizeURL:aURL];
	NSDictionary *attributes = [fm attributesOfItemAtPath:[url path] error:&error];
	aBlock(url, attributes, error);
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
		     onCompletion:(void (^)(NSURL *, NSError *))aBlock
{
	DEBUG(@"url = %@", aURL);
	NSError *error = nil;
	[data writeToURL:aURL options:NSDataWritingAtomic error:&error];
	aBlock([self normalizeURL:aURL], error);
	return nil;
}

@end
