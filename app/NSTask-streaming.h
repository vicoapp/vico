#import "ViBufferedStream.h"

@interface NSTask (streaming)

- (ViBufferedStream *)scheduledStreamWithStandardInput:(NSData *)stdinData;

@end
