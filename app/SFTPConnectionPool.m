#import "SFTPConnectionPool.h"
#import "logging.h"

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

- (id<ViDeferred>)connectionWithHost:(NSString *)hostname
				user:(NSString *)username
			   onConnect:(SFTPRequest *(^)(SFTPConnection *, NSError *))connectCallback
{
	NSString *key;
	if ([username length] > 0)
		key = [NSString stringWithFormat:@"%@@%@", username, hostname];
	else
		key = hostname;
	SFTPConnection *conn = [connections objectForKey:key];

	if (conn && [conn closed]) {
		[connections removeObjectForKey:key];
		conn = nil;
	}

	if (conn == nil) {
		NSError *error = nil;
		conn = [[SFTPConnection alloc] initWithHost:hostname user:username error:&error];
		if (conn == nil || error) {
			return connectCallback(nil, error);
		}

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

- (id<ViDeferred>)connectionWithURL:(NSURL *)url
			  onConnect:(SFTPRequest *(^)(SFTPConnection *, NSError *))connectCallback
{
	return [self connectionWithHost:[url host] user:[url user] onConnect:connectCallback];
}

@end

