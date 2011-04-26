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

- (NSDictionary *)attribsToDictionary:(Attrib *)a
{
	NSString *fileType = nil;
	if (S_ISREG(a->perm))
		fileType = NSFileTypeRegular;
	else if (S_ISDIR(a->perm))
		fileType = NSFileTypeDirectory;
	else if (S_ISLNK(a->perm))
		fileType = NSFileTypeSymbolicLink;
	else if (S_ISSOCK(a->perm))
		fileType = NSFileTypeSocket;
	else if (S_ISBLK(a->perm))
		fileType = NSFileTypeBlockSpecial;
	else if (S_ISCHR(a->perm))
		fileType = NSFileTypeCharacterSpecial;
	else
		fileType = NSFileTypeUnknown;

	NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithUnsignedLong:a->gid], NSFileGroupOwnerAccountID,
		[NSNumber numberWithUnsignedLong:a->uid], NSFileOwnerAccountID,
		[NSNumber numberWithUnsignedLong:a->perm], NSFilePosixPermissions,
		[NSNumber numberWithUnsignedLongLong:a->size], NSFileSize,
		[NSDate dateWithTimeIntervalSince1970:a->mtime], NSFileModificationDate,
		fileType, NSFileType,
		nil];

	return attributes;
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
		return NO;
	}

	NSArray *files = [conn contentsOfDirectoryAtPath:[aURL path] error:&error];
	DEBUG(@"got contents %@, error is %@", files, error);
	NSMutableArray *contents = [NSMutableArray array];
	for (SFTPDirectoryEntry *entry in files)
		[contents addObject:[NSArray arrayWithObjects:entry.filename,
		    [self attribsToDictionary:entry.attributes], nil]];
	aBlock(contents, error);
	return NO;
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
		return NO;
	}

	[conn createDirectory:[aURL path]
			error:&error];
	aBlock(error);
	return NO;
}

- (id<ViDeferred>)fileExistsAtURL:(NSURL *)aURL
		     onCompletion:(void (^)(BOOL result, BOOL isDirectory, NSError *error))aBlock
{
	DEBUG(@"url = %@", aURL);

	NSError *error = nil;
	SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:aURL
									    error:&error];
	if (error) {
		aBlock(NO, NO, error);
		return NO;
	}

	BOOL result = NO, isDirectory = NO;
	result = [conn fileExistsAtPath:[aURL path] isDirectory:&isDirectory error:&error];
	aBlock(result, isDirectory, error);
	return NO;
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
		return NO;
	}

	[conn renameItemAtPath:[srcURL path] toPath:[dstURL path] error:&error];
	aBlock(error);
	return NO;
}

- (id<ViDeferred>)removeItemAtURL:(NSURL *)aURL onCompletion:(void (^)(NSError *error))aBlock
{
	DEBUG(@"url = %@", aURL);

	NSError *error = nil;
	SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:aURL
									    error:&error];
	if (error) {
		aBlock(error);
		return NO;
	}

	[conn removeItemAtPath:[aURL path] error:&error];
	aBlock(error);
	return NO;
}

- (id<ViDeferred>)attributesOfItemAtURL:(NSURL *)aURL
			   onCompletion:(void (^)(NSDictionary *attributes, NSError *error))aBlock
{
	DEBUG(@"url = %@", aURL);

	NSError *error = nil;
	SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:aURL
									    error:&error];
	if (error) {
		aBlock(nil, error);
		return NO;
	}

	Attrib *a = [conn stat:[aURL path] error:&error];
	if (a == nil) {
		aBlock(nil, error);
		return NO;
	}
	aBlock([self attribsToDictionary:a], error);
	return NO;
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
		return NO;
	}

	NSData *data = [conn dataWithContentsOfFile:[aURL path]
					      error:&error];
	dataCallback(data);
	completionCallback(error);
	return NO;
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
		return NO;
	}

	[conn writeData:data toFile:[aURL path] error:&error];
	aBlock(error);
	return NO;
}

@end
