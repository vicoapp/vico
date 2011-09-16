#import "ViBufferedStream.h"

@interface NSTask (streaming)

- (ViBufferedStream *)scheduledStreamWithStandardInput:(NSData *)stdinData captureStandardError:(BOOL)captureStderr;
- (ViBufferedStream *)scheduledStreamWithStandardInput:(NSData *)stdinData;

@end
