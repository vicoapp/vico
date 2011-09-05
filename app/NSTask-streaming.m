#import "NSTask-streaming.h"

@implementation NSTask (streaming)

- (ViBufferedStream *)scheduledStreamWithInput:(NSData *)stdinData
{
	if (stdinData)
		[self setStandardInput:[NSPipe pipe]];
	else
		[self setStandardInput:[NSFileHandle fileHandleWithNullDevice]];
	[self setStandardOutput:[NSPipe pipe]];

        // NSLog("launching #{(self launchPath)} with arguments #{((self arguments) description)}");
        [self launch];
        // NSLog("launched task with pid #{(self processIdentifier)}");

	ViBufferedStream *stream = [ViBufferedStream streamWithTask:self];
	if (stdinData)
		[stream writeData:stdinData];

        [stream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	return stream;
}

@end
