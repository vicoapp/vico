#import "ExEnvironment.h"
#import "ExCommand.h"
#import "ViTheme.h"
#import "ViThemeStore.h"
#import "ViTextView.h"
#import "ViWindowController.h"
#import "ViDocumentView.h"
#import "ViTextStorage.h"
#import "ViCharsetDetector.h"
#import "ViDocumentController.h"
#import "ViBundleStore.h"
#import "NSString-scopeSelector.h"
#import "ViURLManager.h"
#import "ViTransformer.h"
#import "ViError.h"
#import "ViAppController.h"
#import "ViCommon.h"
#include "logging.h"

@interface ExEnvironment (private)
- (IBAction)finishedExCommand:(id)sender;
@end

@implementation ExEnvironment

@synthesize window;

- (void)awakeFromNib
{
	[statusbar setFont:[NSFont userFixedPitchFontOfSize:12.0]];
	[statusbar setDelegate:self];

	[[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(firstResponderChanged:)
                                                     name:ViFirstResponderChangedNotification
                                                   object:nil];
}

#pragma mark -

#pragma mark -
#pragma mark Input of ex commands

- (void)cancel_ex_command
{
	[statusbar setStringValue:@""];
	[statusbar setEditable:NO];
	[statusbar setHidden:YES];
	[messageField setHidden:NO];
	[projectDelegate cancelExplorer];

	[[window windowController] focusEditor];
}

- (void)execute_ex_command:(NSString *)exCommand
{
	exString = exCommand;

	if (busy)
		[NSApp stopModalWithCode:0];
	busy = NO;
	[self cancel_ex_command];
}

- (void)firstResponderChanged:(NSNotification *)notification
{
	NSView *view = [notification object];
	if (busy && view != statusbar) {
		[NSApp stopModalWithCode:1];
		busy = NO;
	}
}

- (NSString *)getExStringForCommand:(ViCommand *)command
{
	ViMacro *macro = command.macro;

	if (busy) {
		INFO(@"%s", "can't handle nested ex commands!");
		return nil;
	}

	[messageField setHidden:YES];
	[statusbar setHidden:NO];
	[statusbar setEditable:YES];
	[window makeFirstResponder:statusbar];

	busy = YES;
	exString = nil;

	if (macro) {
		NSInteger keyCode;
		ViTextView *editor = (ViTextView *)[window fieldEditor:YES forObject:statusbar];
		while (busy && (keyCode = [macro pop]) != -1)
			[editor.keyManager handleKey:keyCode];
	}

	if (busy) {
		[NSApp runModalForWindow:window];
		busy = NO;
	}

	return exString;
}

#pragma mark -
#pragma mark Pipe Filtering

- (void)filterFinish
{
	DEBUG(@"wait until exit of command %@", filterCommand);
	[filterTask waitUntilExit];
	int status = [filterTask terminationStatus];
	DEBUG(@"status = %d", status);

	if (filterFailed)
		status = -1;

	/* Try to auto-detect the encoding. */
	NSStringEncoding encoding = [[ViCharsetDetector defaultDetector] encodingForData:filterOutput];
	if (encoding == 0)
		/* Try UTF-8 if auto-detecting fails. */
		encoding = NSUTF8StringEncoding;
	NSString *outputText = [[NSString alloc] initWithData:filterOutput encoding:encoding];
	if (outputText == nil) {
		/* If all else fails, use iso-8859-1. */
		encoding = NSISOLatin1StringEncoding;
		outputText = [[NSString alloc] initWithData:filterOutput encoding:encoding];
	}

	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[filterTarget methodSignatureForSelector:filterSelector]];
	[invocation setSelector:filterSelector];
	[invocation setArgument:&status atIndex:2];
	[invocation setArgument:&outputText atIndex:3];
	[invocation setArgument:&filterContextInfo atIndex:4];
	[invocation invokeWithTarget:filterTarget];

	filterTask = nil;
	filterCommand = nil;
	filterOutput = nil;
	filterTarget = nil;
	filterContextInfo = nil;
}

- (void)filterSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];

	if (returnCode == -1) {
		DEBUG(@"terminating filter task %@", filterTask);
		[filterTask terminate];
	}
	
	[filterIndicator stopAnimation:self];
	[self filterFinish];
}

- (IBAction)filterCancel:(id)sender
{
	[NSApp endSheet:filterSheet returnCode:-1];
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)event
{
	DEBUG(@"got event %lu on stream %@", event, stream);

	const void *ptr;
	NSUInteger len;

	switch (event) {
	case NSStreamEventNone:
	case NSStreamEventOpenCompleted:
	default:
		break;
	case NSStreamEventHasBytesAvailable:
		[filterStream getBuffer:&ptr length:&len];
		DEBUG(@"got %lu bytes", len);
		if (len > 0) {
			[filterOutput appendBytes:ptr length:len];
		}
		break;
	case NSStreamEventHasSpaceAvailable:
		/* All output data flushed. */
		[filterStream shutdownWrite];
		break;
	case NSStreamEventErrorOccurred:
		INFO(@"error on stream %@: %@", stream, [stream streamError]);
		filterFailed = 1;
		break;
	case NSStreamEventEndEncountered:
		DEBUG(@"EOF on stream %@", stream);
		if ([window attachedSheet] != nil)
			[NSApp endSheet:filterSheet returnCode:0];
		filterDone = YES;
		break;
	}
}

- (void)filterText:(NSString *)inputText
       throughTask:(NSTask *)task
            target:(id)target
          selector:(SEL)selector
       contextInfo:(id)contextInfo
      displayTitle:(NSString *)displayTitle
{
	filterTask = task;

	NSPipe *shellInput = [NSPipe pipe];
	NSPipe *shellOutput = [NSPipe pipe];

	[filterTask setStandardInput:shellInput];
	[filterTask setStandardOutput:shellOutput];
	//[filterTask setStandardError:shellOutput];

	[filterTask launch];

	// setup a new runloop mode
	// schedule read and write in this mode
	// schedule a timer to track how long the task takes to complete
	// if not finished within x seconds, show a modal sheet, re-adding the runloop sources to the modal sheet runloop(?)
	// accept cancel button from sheet -> terminate task and cancel filter

	NSString *mode = NSDefaultRunLoopMode; //ViFilterRunLoopMode;

	filterStream = [[ViBufferedStream alloc] initWithTask:filterTask];
	[filterStream setDelegate:self];

	filterOutput = [NSMutableData dataWithCapacity:[inputText length]];
	[filterStream writeData:[inputText dataUsingEncoding:NSUTF8StringEncoding]];

	filterDone = NO;
	filterFailed = NO;

	filterTarget = target;
	filterSelector = selector;
	filterContextInfo = contextInfo;


	/* schedule the read and write sources in the new runloop mode */
	[filterStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:mode];

	NSDate *limitDate = [NSDate dateWithTimeIntervalSinceNow:2.0];

	int done = 0;

	for (;;) {
		[[NSRunLoop currentRunLoop] runMode:mode beforeDate:limitDate];
		if ([limitDate timeIntervalSinceNow] <= 0) {
			DEBUG(@"limit date %@ reached", limitDate);
			break;
		}

		if (filterFailed) {
			DEBUG(@"%s", "filter I/O failed");
			[filterTask terminate];
			done = -1;
			break;
		}

		if (filterDone) {
			done = 1;
			break;
		}
	}

	if (done) {
		[self filterFinish];
	} else {
		[NSApp beginSheet:filterSheet
                   modalForWindow:window
                    modalDelegate:self
                   didEndSelector:@selector(filterSheetDidEnd:returnCode:contextInfo:)
                      contextInfo:NULL];
		[filterLabel setStringValue:displayTitle];
		[filterLabel setFont:[NSFont userFixedPitchFontOfSize:12.0]];
		[filterIndicator startAnimation:self];
		[filterStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:mode];
	}
}

- (void)filterText:(NSString *)inputText
    throughCommand:(NSString *)shellCommand
            target:(id)target
          selector:(SEL)selector
       contextInfo:(id)contextInfo
{
	if ([shellCommand length] == 0)
		return;

	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:@"/bin/bash"];
	[task setArguments:[NSArray arrayWithObjects:@"-c", shellCommand, nil]];

	filterCommand = shellCommand;

	return [self filterText:inputText
		    throughTask:task
			 target:target
		       selector:selector
		    contextInfo:contextInfo
		   displayTitle:shellCommand];
}


@end

