#import "ViBufferedStream.h"

@interface NSTask (streaming)

- (ViBufferedStream *)streamWithInput:(NSData *)stdinData;

@end
