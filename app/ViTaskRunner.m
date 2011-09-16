#import "ViTaskRunner.h"
#import "NSTask-streaming.h"
#import "ViCharsetDetector.h"
#import "ViError.h"
#import "ViCommon.h"
#include "logging.h"

@implementation ViTaskRunner

@synthesize task, window, stream, stdout, stderr, status, cancelled;

- (ViTaskRunner *)init
{
	if ((self = [super init]) != nil) {
		[NSBundle loadNibNamed:@"WaitProgress" owner:self];
	}
	return self;
}

- (NSString *)stdoutString
{
	/* Try to auto-detect the encoding. */
	NSStringEncoding encoding = [[ViCharsetDetector defaultDetector] encodingForData:stdout];
	if (encoding == 0)
		/* Try UTF-8 if auto-detecting fails. */
		encoding = NSUTF8StringEncoding;
	NSString *outputText = [[NSString alloc] initWithData:stdout encoding:encoding];
	if (outputText == nil) {
		/* If all else fails, use iso-8859-1. */
		encoding = NSISOLatin1StringEncoding;
		outputText = [[NSString alloc] initWithData:stdout encoding:encoding];
	}

	return outputText;
}

- (void)finish
{
	if (![task isRunning])
		DEBUG(@"task %@ is no longer running", task);
	else {
		DEBUG(@"wait until exit of task %@", task);
		[task waitUntilExit];
	}
	status = [task terminationStatus];
	DEBUG(@"status = %d", status);

	[stream close];

	if (target && selector) {
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[target methodSignatureForSelector:selector]];
		[invocation setSelector:selector];
		[invocation setArgument:&self atIndex:2];
		[invocation setArgument:&status atIndex:3];
		[invocation setArgument:&contextInfo atIndex:4];
		[invocation invokeWithTarget:target];
	}

	stream = nil;
	stdout = nil;
	stderr = nil;
	target = nil;
	contextInfo = nil;
}

- (void)waitSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];

	if (returnCode == -1) {
		DEBUG(@"terminating filter task %@", task);
		[task terminate];
	}

	[progressIndicator stopAnimation:self];
	[self finish];
}

- (IBAction)cancelTask:(id)sender
{
	cancelled = YES;
	[NSApp endSheet:waitWindow returnCode:-1];
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)event
{
	DEBUG(@"got event %lu on stream %@", event, aStream);

	const void *ptr;
	NSUInteger len;

	switch (event) {
	case NSStreamEventNone:
	case NSStreamEventOpenCompleted:
	default:
		break;
	case NSStreamEventHasBytesAvailable:
		[stream getBuffer:&ptr length:&len];
		DEBUG(@"got %lu bytes", len);
		if (len > 0)
			[stdout appendBytes:ptr length:len];
		break;
	case NSStreamEventHasSpaceAvailable:
		/* All output data flushed. */
		[stream shutdownWrite];
		[[[task standardInput] fileHandleForWriting] closeFile];
		break;
	case NSStreamEventErrorOccurred:
		INFO(@"error on stream %@: %@", stream, [stream streamError]);
		if ([window attachedSheet] != nil)
			[NSApp endSheet:waitWindow returnCode:-1];
		failed = 1;
		break;
	case NSStreamEventEndEncountered:
		DEBUG(@"EOF on stream %@", stream);
		if ([window attachedSheet] != nil)
			[NSApp endSheet:waitWindow returnCode:0];
		done = YES;
		break;
	case ViStreamEventWriteEndEncountered:
		DEBUG(@"EOF on write stream %@; we keep reading", stream);
		break;
	}
}

- (void)launchTask:(NSTask *)aTask
 withStandardInput:(NSData *)stdin
synchronouslyInWindow:(NSWindow *)aWindow
	     title:(NSString *)displayTitle
	    target:(id)aTarget
	  selector:(SEL)aSelector
       contextInfo:(id)contextObject
{
	NSParameterAssert(aWindow);
	NSParameterAssert(displayTitle);
	NSAssert(![task isRunning], @"Task is already running");

	task = aTask;
	window = aWindow;
	stdout = [NSMutableData data];
	stderr = [NSMutableData data];

	stream = [task scheduledStreamWithStandardInput:stdin captureStandardError:YES];
	[stream setDelegate:self];

	status = -1;
	done = NO;
	failed = NO;
	cancelled = NO;
	target = aTarget;
	selector = aSelector;
	contextInfo = contextObject;

	NSDate *limitDate = [NSDate dateWithTimeIntervalSinceNow:2.0];

	for (;;) {
		DEBUG(@"running until %@", limitDate);
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:limitDate];
		if ([limitDate timeIntervalSinceNow] <= 0) {
			DEBUG(@"limit date %@ reached", limitDate);
			break;
		}

		if (failed) {
			DEBUG(@"%s", "filter I/O failed");
			[task terminate];
			done = YES;
			break;
		}

		if (done)
			break;
	}

	if (done) {
		[self finish];
	} else {
		[NSApp beginSheet:waitWindow
                   modalForWindow:window
                    modalDelegate:self
                   didEndSelector:@selector(waitSheetDidEnd:returnCode:contextInfo:)
                      contextInfo:NULL];
		[waitLabel setStringValue:displayTitle];
		[waitLabel setFont:[NSFont userFixedPitchFontOfSize:12.0]];
		[progressIndicator startAnimation:self];
	}
}

@end
