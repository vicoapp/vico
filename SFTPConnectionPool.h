#import <Cocoa/Cocoa.h>
#import "SFTPConnection.h"

@interface SFTPConnectionPool : NSObject
{
	NSMutableDictionary *connections;
}

+ (SFTPConnectionPool *)sharedPool;
- (SFTPConnection *)connectionWithURL:(NSURL *)url error:(NSError **)outError;
- (SFTPConnection *)connectionWithHost:(NSString *)hostname user:(NSString *)username error:(NSError **)outError;

@end
