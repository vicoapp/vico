#import <Cocoa/Cocoa.h>
#import "SFTPConnection.h"

@interface SFTPConnectionPool : NSObject
{
	NSMutableDictionary *connections;
}

+ (SFTPConnectionPool *)sharedPool;

- (id<ViDeferred>)connectionWithHost:(NSString *)hostname
				user:(NSString *)username
			   onConnect:(SFTPRequest *(^)(SFTPConnection *, NSError *))connectCallback;

- (id<ViDeferred>)connectionWithURL:(NSURL *)url
			  onConnect:(SFTPRequest *(^)(SFTPConnection *, NSError *))connectCallback;

@end
