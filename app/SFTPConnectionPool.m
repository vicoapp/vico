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

- (id<ViDeferred>)connectionWithURL:(NSURL *)url
			  onConnect:(SFTPRequest *(^)(SFTPConnection *, NSError *))connectCallback
{
	NSString *username = [url user];
	NSString *hostname = [url host];
	NSNumber *port = [url port];

	if (hostname == nil)
		return connectCallback(nil, [ViError errorWithFormat:@"missing hostname in URL %@", url]);

	NSString *key = [NSString stringWithFormat:@"%@@%@:%@", username ?: @"", hostname, port ?: @"22"];
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

