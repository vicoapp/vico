#import <Cocoa/Cocoa.h>
#import "SFTPConnection.h"

@interface SFTPConnectionPool : NSObject
{
	NSMutableDictionary *connections;
}

+ (SFTPConnectionPool *)sharedPool;
- (SFTPConnection *)connectionWithTarget:(NSString *)aTarget;

@end
