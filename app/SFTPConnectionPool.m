#import "SFTPConnectionPool.h"
#import "ViError.h"
#include "logging.h"

@implementation SFTPConnectionPool

- (SFTPConnectionPool *)init
{
	if ((self = [super init]) != nil) {
		_connections = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[_connections release];
	[super dealloc];
}

+ (SFTPConnectionPool *)sharedPool
{
	static SFTPConnectionPool *__sharedPool = nil;
	if (__sharedPool == nil)
		__sharedPool = [[SFTPConnectionPool alloc] init];
	return __sharedPool;
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
	SFTPConnection *conn = [_connections objectForKey:key];
	if (conn && [conn connected])
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
	SFTPConnection *conn = [_connections objectForKey:key];

	if (conn && [conn closed]) {
		DEBUG(@"connection %@ is closed", conn);
		[_connections removeObjectForKey:key];
		conn = nil;
	}

	if (conn == nil) {
		NSError *error = nil;
		conn = [[[SFTPConnection alloc] initWithURL:url error:&error] autorelease];
		if (conn == nil || error)
			return connectCallback(nil, error);

		[_connections setObject:conn forKey:key];

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

