#import <Cocoa/Cocoa.h>
#import "SFTPConnection.h"

@interface SFTPConnectionPool : NSObject
{
	NSMutableDictionary *_connections;
}

+ (SFTPConnectionPool *)sharedPool;

- (NSURL *)normalizeURL:(NSURL *)aURL;

- (id<ViDeferred>)connectionWithURL:(NSURL *)url
			  onConnect:(SFTPRequest *(^)(SFTPConnection *, NSError *))connectCallback;

@end
