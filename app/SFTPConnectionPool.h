#import <Cocoa/Cocoa.h>
#import "SFTPConnection.h"

@interface SFTPConnectionPool : NSObject
{
	NSMutableDictionary *connections;
}

+ (SFTPConnectionPool *)sharedPool;

- (id<ViDeferred>)connectionWithURL:(NSURL *)url
			  onConnect:(SFTPRequest *(^)(SFTPConnection *, NSError *))connectCallback;

@end
