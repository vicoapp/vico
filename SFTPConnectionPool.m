#import "SFTPConnectionPool.h"
#import "logging.h"

@implementation SFTPConnectionPool

- (SFTPConnectionPool *)init
{
	self = [super init];
	if (self)
	{
		connections = [[NSMutableDictionary alloc] init];
	}
	return self;
}

+ (SFTPConnectionPool *)sharedPool
{
	static SFTPConnectionPool *sharedPool = nil;
	if (sharedPool == nil)
	{
		sharedPool = [[SFTPConnectionPool alloc] init];
	}
	return sharedPool;
}

- (SFTPConnection *)connectionWithTarget:(NSString *)aTarget
{
	SFTPConnection *conn = [connections objectForKey:aTarget];
	INFO(@"conn %@ = %@", aTarget, conn);
	INFO(@"all connections = %@", connections);
	if (conn == nil)
	{
		conn = [[SFTPConnection alloc] initWithTarget:aTarget];
		INFO(@"conn = %@", conn);
		if (conn)
		{
			[connections setObject:conn forKey:aTarget];
		}
	}
	return conn;
}

@end

