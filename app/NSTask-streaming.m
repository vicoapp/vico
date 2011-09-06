#import "NSTask-streaming.h"
#include "logging.h"

@implementation NSTask (streaming)

- (ViBufferedStream *)scheduledStreamWithStandardInput:(NSData *)stdinData
{
	if (stdinData)
		[self setStandardInput:[NSPipe pipe]];
	else
		[self setStandardInput:[NSFileHandle fileHandleWithNullDevice]];
	[self setStandardOutput:[NSPipe pipe]];

        DEBUG(@"launching %@ with arguments %@", [self launchPath], [self arguments]);
        [self launch];
        DEBUG(@"launched task with pid %li", [self processIdentifier]);

	ViBufferedStream *stream = [ViBufferedStream streamWithTask:self];
	if (stdinData)
		[stream writeData:stdinData];

        [stream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	return stream;
}

@end
