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

- (NSURL *)normalizeURL:(NSURL *)aURL
{
	return aURL;
}

- (id<ViDeferred>)attributesOfItemAtURL:(NSURL *)aURL
			   onCompletion:(void (^)(NSURL *, NSDictionary *, NSError *))aBlock
{
	DEBUG(@"url = %@", aURL);

	return [[SFTPConnectionPool sharedPool] connectionWithURL:aURL onConnect:^(SFTPConnection *conn, NSError *error) {
		if (!error)
			return [conn attributesOfItemAtURL:aURL onResponse:aBlock];
		aBlock(nil, nil, error);
		return nil;
	}];
}

- (id<ViDeferred>)fileExistsAtURL:(NSURL *)aURL
		     onCompletion:(void (^)(NSURL *, BOOL, NSError *))aBlock
{
	DEBUG(@"url = %@", aURL);

	return [[SFTPConnectionPool sharedPool] connectionWithURL:aURL onConnect:^(SFTPConnection *conn, NSError *error) {
		if (!error)
			return [conn fileExistsAtURL:aURL onResponse:aBlock];
		aBlock(nil, NO, error);
		return nil;
	}];
}

- (id<ViDeferred>)contentsOfDirectoryAtURL:(NSURL *)aURL
			      onCompletion:(void (^)(NSArray *contents, NSError *error))aBlock
{
	DEBUG(@"url = %@", aURL);

	return [[SFTPConnectionPool sharedPool] connectionWithURL:aURL onConnect:^(SFTPConnection *conn, NSError *error) {
		if (!error)
			return [conn contentsOfDirectoryAtPath:[aURL path] onResponse:aBlock];
		aBlock(nil, error);
		return nil;
	}];
}

- (id<ViDeferred>)createDirectoryAtURL:(NSURL *)aURL
			  onCompletion:(void (^)(NSError *error))aBlock
{
	DEBUG(@"url = %@", aURL);

	return [[SFTPConnectionPool sharedPool] connectionWithURL:aURL onConnect:^(SFTPConnection *conn, NSError *error) {
		if (!error)
			return [conn createDirectory:[aURL path] onResponse:aBlock];
		aBlock(error);
		return nil;
	}];
}

- (id<ViDeferred>)moveItemAtURL:(NSURL *)srcURL
			  toURL:(NSURL *)dstURL
		   onCompletion:(void (^)(NSError *error))aBlock
{
	DEBUG(@"%@ -> %@", srcURL, dstURL);

	return [[SFTPConnectionPool sharedPool] connectionWithURL:srcURL onConnect:^(SFTPConnection *conn, NSError *error) {
		if (!error)
			return [conn renameItemAtPath:[srcURL path]
					       toPath:[dstURL path]
					   onResponse:aBlock];
		aBlock(error);
		return nil;
	}];
}

- (id<ViDeferred>)removeItemAtURL:(NSURL *)aURL
		     onCompletion:(void (^)(NSError *error))aBlock
{
	DEBUG(@"url = %@", aURL);

	return [[SFTPConnectionPool sharedPool] connectionWithURL:aURL onConnect:^(SFTPConnection *conn, NSError *error) {
		if (!error)
			return [conn removeItemAtPath:[aURL path] onResponse:aBlock];
		aBlock(error);
		return nil;
	}];
}

- (id<ViDeferred>)dataWithContentsOfURL:(NSURL *)aURL
				 onData:(void (^)(NSData *data))dataCallback
			   onCompletion:(void (^)(NSURL *, NSDictionary *, NSError *))completionCallback
{
	DEBUG(@"url = %@", aURL);

	return [[SFTPConnectionPool sharedPool] connectionWithURL:aURL onConnect:^(SFTPConnection *conn, NSError *error) {
		if (!error)
			return [conn dataWithContentsOfURL:aURL
						    onData:dataCallback
						onResponse:completionCallback];
		completionCallback(nil, nil, error);
		return nil;
	}];
}

- (id<ViDeferred>)writeDataSafely:(NSData *)data
			    toURL:(NSURL *)aURL
		     onCompletion:(void (^)(NSError *error))aBlock
{
	DEBUG(@"url = %@", aURL);

	return [[SFTPConnectionPool sharedPool] connectionWithURL:aURL onConnect:^(SFTPConnection *conn, NSError *error) {
		if (!error)
			return [conn writeDataSefely:data toFile:[aURL path] onResponse:aBlock];
		aBlock(error);
		return nil;
	}];
}

@end
