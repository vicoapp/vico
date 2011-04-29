#define FORCE_DEBUG
#import "ViSFTPURLHandler.h"
#import "SFTPConnectionPool.h"
#include "logging.h"

@implementation ViSFTPURLHandler

- (id)init
{
	if ((self = [super init]) != nil) {
		;
	}

	return self;
}

- (BOOL)respondsToURL:(NSURL *)aURL
{
	return [[aURL scheme] isEqualToString:@"sftp"];
}

- (id<ViDeferred>)contentsOfDirectoryAtURL:(NSURL *)aURL
			      onCompletion:(void (^)(NSArray *contents, NSError *error))aBlock
{
	DEBUG(@"url = %@", aURL);

	NSError *error = nil;
	SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:aURL
									    error:&error];
	if (error) {
		aBlock(nil, error);
		return nil;
	}

	[conn contentsOfDirectoryAtPath:[aURL path] onResponse:aBlock];
	return nil; // XXX: return a deferred object!
}

- (id<ViDeferred>)createDirectoryAtURL:(NSURL *)aURL
			  onCompletion:(void (^)(NSError *error))aBlock
{
	DEBUG(@"url = %@", aURL);

	NSError *error = nil;
	SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:aURL
									    error:&error];
	if (error) {
		aBlock(error);
		return nil;
	}

	[conn createDirectory:[aURL path] onResponse:aBlock];
	return nil; // XXX: return a deferred object!
}

- (id<ViDeferred>)fileExistsAtURL:(NSURL *)aURL
		     onCompletion:(void (^)(BOOL, BOOL, NSError *))aBlock
{
	DEBUG(@"url = %@", aURL);

	NSError *error = nil;
	SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:aURL
									    error:&error];
	if (error) {
		aBlock(NO, NO, error);
		return nil;
	}

	// [aBlock copy];

	[conn fileExistsAtPath:[aURL path] onResponse:aBlock];
	return nil; // FIXME: return a deferred
}

- (id<ViDeferred>)moveItemAtURL:(NSURL *)srcURL
			  toURL:(NSURL *)dstURL
		   onCompletion:(void (^)(NSError *error))aBlock
{
	DEBUG(@"%@ -> %@", srcURL, dstURL);

	NSError *error = nil;
	SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:srcURL
									    error:&error];
	if (error) {
		aBlock(error);
		return nil;
	}

	[conn renameItemAtPath:[srcURL path]
			toPath:[dstURL path]
		    onResponse:aBlock];
	return nil; // FIXME: deferred
}

- (id<ViDeferred>)removeItemAtURL:(NSURL *)aURL
		     onCompletion:(void (^)(NSError *error))aBlock
{
	DEBUG(@"url = %@", aURL);

	NSError *error = nil;
	SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:aURL
									    error:&error];
	if (error) {
		aBlock(error);
		return nil;
	}

	[conn removeItemAtPath:[aURL path] onResponse:aBlock];
	return nil; // FIXME: deferred
}

- (id<ViDeferred>)attributesOfItemAtURL:(NSURL *)aURL
			   onCompletion:(void (^)(NSDictionary *, NSError *))aBlock
{
	DEBUG(@"url = %@", aURL);

	NSError *error = nil;
	SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:aURL
									    error:&error];
	if (error) {
		aBlock(nil, error);
		return nil;
	}

	[conn attributesOfItemAtPath:[aURL path] onResponse:aBlock];
	return nil; // FIXME:
}

- (id<ViDeferred>)dataWithContentsOfURL:(NSURL *)aURL
				 onData:(void (^)(NSData *data))dataCallback
			   onCompletion:(void (^)(NSError *error))completionCallback
{
	DEBUG(@"url = %@", aURL);

	NSError *error = nil;
	SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:aURL
									    error:&error];
	if (error) {
		completionCallback(error);
		return nil;
	}

	return [conn dataWithContentsOfFile:[aURL path]
				     onData:dataCallback
				 onResponse:completionCallback];
}

- (id<ViDeferred>)writeDataSafely:(NSData *)data
			    toURL:(NSURL *)aURL
		     onCompletion:(void (^)(NSError *error))aBlock
{
	DEBUG(@"url = %@", aURL);

	NSError *error = nil;
	SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:aURL
									    error:&error];
	if (error) {
		aBlock(error);
		return nil;
	}

	[conn writeData:data toFile:[aURL path] error:&error];
	aBlock(error);
	return nil;
}

@end
