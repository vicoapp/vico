#import "SFTPConnectionPool.h"
#import "ViError.h"
#include "logging.h"

@implementation SFTPConnectionPool

- (SFTPConnectionPool *)init
{
	self = [super init];
	if (self) {
		connections = [NSMutableDictionary dictionary];
	}
	return self;
}

+ (SFTPConnectionPool *)sharedPool
{
	static SFTPConnectionPool *sharedPool = nil;
	if (sharedPool == nil)
		sharedPool = [[SFTPConnectionPool alloc] init];
	return sharedPool;
}

- (NSString *)connectionKeyForURL:(NSURL *)aURL
{
	NSString *username = [aURL user];
	NSString *hostname = [aURL host];
	NSNumber *port = [aURL port];
	return [NSString stringWithFormat:@"%@@%@:%@", username ?: @"", hostname, port ?: @"22"];
}

- (NSURL *)normalizeURL:(NSURL *)aURL
{
	NSString *key = [self connectionKeyForURL:aURL];
	SFTPConnection *conn = [connections objectForKey:key];
	if (conn)
		return [conn normalizeURL:aURL];
	return aURL;
}

- (id<ViDeferred>)connectionWithURL:(NSURL *)url
			  onConnect:(SFTPRequest *(^)(SFTPConnection *, NSError *))connectCallback
{
	if ([url host] == nil)
		return connectCallback(nil,
		    [ViError errorWithFormat:@"missing hostname in URL %@", url]);

	NSString *key = [self connectionKeyForURL:url];
	SFTPConnection *conn = [connections objectForKey:key];

	if (conn && [conn closed]) {
		[connections removeObjectForKey:key];
		conn = nil;
	}

	if (conn == nil) {
		NSError *error = nil;
		conn = [[SFTPConnection alloc] initWithURL:url error:&error];
		if (conn == nil || error)
			return connectCallback(nil, error);

		[connections setObject:conn forKey:key];

		__block SFTPRequest *initRequest = nil;
		void (^initCallback)(NSError *) = ^(NSError *error) {
			initRequest.subRequest = connectCallback(conn, error);
		};
		initRequest = [conn onConnect:initCallback];
		return initRequest;
	} else
		return connectCallback(conn, nil);

	return nil;
}

@end

