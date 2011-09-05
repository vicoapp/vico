#import "ViBufferedStream.h"

@interface NSTask (streaming)

- (ViBufferedStream *)scheduledStreamWithInput:(NSData *)stdinData;

@end
