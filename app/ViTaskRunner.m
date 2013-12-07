/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ViTaskRunner.h"
#import "NSTask-streaming.h"
#import "ViCharsetDetector.h"
#import "ViError.h"
#import "ViCommon.h"
#include "logging.h"

#include <signal.h>
#include <sys/types.h>
#include <sys/stat.h>

@implementation ViTaskRunner

@synthesize task = _task;
@synthesize window = _window;
@synthesize stream = _stream;
@synthesize standardOutput = _stdout;
@synthesize standardError = _stderr;
@synthesize contextInfo = _contextInfo;
@synthesize target = _target;
@synthesize status = _status;
@synthesize cancelled = _cancelled;

- (ViTaskRunner *)init
{
	if ((self = [super init]) != nil) {
		if (![[NSBundle mainBundle] loadNibNamed:@"WaitProgress" owner:self topLevelObjects:nil]) {
			return nil;
		}
	}
	DEBUG_INIT();
	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	if ([_task isRunning]) {
		kill([_task processIdentifier], SIGKILL);
	}
	 // Top-level nib object
}

- (NSString *)stdoutString
{
	return [self stringWithData:_stdout];
}

- (NSString *)stderrString
{
	return [self stringWithData:_stderr];
}

- (NSString *)stringWithData:(NSData *)data
{
	/* Try to auto-detect the encoding. */
	NSStringEncoding encoding = [[ViCharsetDetector defaultDetector] encodingForData:data];
	if (encoding == 0)
	/* Try UTF-8 if auto-detecting fails. */
		encoding = NSUTF8StringEncoding;
	NSString *outputText = [[NSString alloc] initWithData:data encoding:encoding];
	if (outputText == nil) {
		/* If all else fails, use iso-8859-1. */
		encoding = NSISOLatin1StringEncoding;
		outputText = [[NSString alloc] initWithData:data encoding:encoding];
	}
	
	return outputText;	
}

- (void)finish
{
	if (![_task isRunning])
		DEBUG(@"task %@ is no longer running", _task);
	else {
		DEBUG(@"wait until exit of task %@", _task);
		[_task waitUntilExit];
	}
	_status = [_task terminationStatus];
	DEBUG(@"status = %d", _status);

	[_stream close];

	if (_target) {
		[_target taskRunner:self finishedWithStatus:_status contextInfo:_contextInfo];
	}

	[self setContextInfo:nil];
	[self setStandardOutput:nil];
	[self setStandardError:nil];
	[self setStream:nil];
	[self setTarget:nil];
	[self setWindow:nil];
}

- (void)waitSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];

	if (returnCode == -1) {
		DEBUG(@"terminating filter task %@", _task);
		[_task terminate];
	}

	[progressIndicator stopAnimation:self];
	[self finish];
}

- (IBAction)cancelTask:(id)sender
{
	_cancelled = YES;
	if (_window)
		[NSApp endSheet:waitWindow returnCode:-1];
	else
		[NSApp abortModal];
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)event
{
	DEBUG(@"got event %lu on stream %@", event, aStream);

	const void *ptr;
	NSUInteger len;

	// cast to int because ViStreamEventWriteEndEncountered is not declared
	// part of the enum, and clang don't like that
	switch ((int)event) {
	case NSStreamEventNone:
	case NSStreamEventOpenCompleted:
	default:
		break;
	case NSStreamEventHasBytesAvailable:
		[_stream getBuffer:&ptr length:&len];
		DEBUG(@"got %lu bytes", len);
		if (len > 0)
			[_stdout appendBytes:ptr length:len];
		break;
	case NSStreamEventHasSpaceAvailable:
		/* All output data flushed. */
		[_stream shutdownWrite];
		[[[_task standardInput] fileHandleForWriting] closeFile];
		break;
	case NSStreamEventErrorOccurred:
		INFO(@"error on stream %@: %@", _stream, [_stream streamError]);
		if (_window == nil)
			[NSApp abortModal];
		else if ([_window attachedSheet] != nil)
			[NSApp endSheet:waitWindow returnCode:-1];
		_failed = 1;
		break;
	case NSStreamEventEndEncountered:
		DEBUG(@"EOF on stream %@", _stream);
		if (_window == nil)
			[NSApp abortModal];
		else if ([_window attachedSheet] != nil)
			[NSApp endSheet:waitWindow returnCode:0];
		_done = YES;
		break;
	case ViStreamEventWriteEndEncountered:
		DEBUG(@"EOF on write stream %@; we keep reading", _stream);
		break;
	}
}

- (void)launchTask:(NSTask *)aTask
 withStandardInput:(NSData *)stdin
asynchronouslyInWindow:(NSWindow *)aWindow
	     title:(NSString *)displayTitle
	    target:(id<ViTaskRunnerTarget>)aTarget
       contextInfo:(id)contextObject
{
	NSParameterAssert(displayTitle);
	NSAssert(![_task isRunning], @"Task is already running");

	[self setTask:aTask];
	[self setWindow:aWindow];
	[self setTarget:aTarget];
	[self setStandardOutput:[NSMutableData data]];
	[self setStandardError:[NSMutableData data]];
	[self setContextInfo:contextObject];

	_status = -1;
	_done = NO;
	_failed = NO;
	_cancelled = NO;

	[self setStream:[_task scheduledStreamWithStandardInput:stdin captureStandardError:YES]];
	[_stream setDelegate:self];

	NSDate *limitDate = [NSDate dateWithTimeIntervalSinceNow:2.0];

	for (;;) {
		DEBUG(@"running until %@", limitDate);
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:limitDate];
		if ([limitDate timeIntervalSinceNow] <= 0) {
			DEBUG(@"limit date %@ reached", limitDate);
			break;
		}

		if (_failed) {
			DEBUG(@"%s", "filter I/O failed");
			[_task terminate];
			_done = YES;
			break;
		}

		if (_done)
			break;
	}

	if (_done) {
		[self finish];
	} else {
		[waitWindow setTitle:@"Waiting on shell command"];
		[waitLabel setStringValue:displayTitle];
		[waitLabel setFont:[NSFont userFixedPitchFontOfSize:12.0]];
		[progressIndicator startAnimation:self];
		if (_window) {
			[NSApp beginSheet:waitWindow
			   modalForWindow:_window
			    modalDelegate:self
			   didEndSelector:@selector(waitSheetDidEnd:returnCode:contextInfo:)
			      contextInfo:NULL];
		} else {
			[_stream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSModalPanelRunLoopMode];
			NSInteger ret = [NSApp runModalForWindow:waitWindow];
			INFO(@"modal returned %li", ret);
			[waitWindow orderOut:nil];
			[self waitSheetDidEnd:nil
				   returnCode:(_cancelled || _failed) ? -1 : 0
				  contextInfo:NULL];
		}
	}
}

- (BOOL)launchShellCommand:(NSString *)shellCommand
	 withStandardInput:(NSData *)stdin
	       environment:(NSDictionary *)environment
	  currentDirectory:(NSString *)currentDirectory
    asynchronouslyInWindow:(NSWindow *)aWindow
		     title:(NSString *)displayTitle
		    target:(id<ViTaskRunnerTarget>)aTarget
	       contextInfo:(id)contextObject
		     error:(NSError **)outError
{
	char *templateFilename = NULL;
	int fd = -1;

	DEBUG(@"shell command = [%@]", shellCommand);
	if ([shellCommand hasPrefix:@"#!"]) {
		const char *tmpl = [[NSTemporaryDirectory()
		    stringByAppendingPathComponent:@"vico_cmd.XXXXXXXXXX"]
		    fileSystemRepresentation];
		DEBUG(@"using template %s", tmpl);
		templateFilename = strdup(tmpl);
		fd = mkstemp(templateFilename);
		if (fd == -1) {
			if (outError)
				*outError = [ViError errorWithFormat:@"Failed to open temporary file: %s", strerror(errno)];
			free(templateFilename);
			return NO;
		}
		const char *data = [shellCommand UTF8String];
		ssize_t rc = write(fd, data, strlen(data));
		DEBUG(@"wrote %i byte", rc);
		if (rc == -1) {
			if (outError)
				*outError = [ViError errorWithFormat:@"Failed to save temporary command file: %s", strerror(errno)];
			unlink(templateFilename);
			close(fd);
			free(templateFilename);
			return NO;
		}
		chmod(templateFilename, 0700);
		NSFileManager *fm = [NSFileManager defaultManager];
		shellCommand = [fm stringWithFileSystemRepresentation:templateFilename
							       length:strlen(templateFilename)];
	}

	NSTask *task = [[NSTask alloc] init];
	if (templateFilename)
		[task setLaunchPath:shellCommand];
	else {
		[task setLaunchPath:@"/bin/bash"];
		[task setArguments:[NSArray arrayWithObjects:@"-c", shellCommand, nil]];
	}

	[task setEnvironment:environment];
	if (currentDirectory)
		[task setCurrentDirectoryPath:currentDirectory];
	else
		[task setCurrentDirectoryPath:NSTemporaryDirectory()];

	[self launchTask:task
	 withStandardInput:stdin
    asynchronouslyInWindow:aWindow
		     title:displayTitle
		    target:aTarget
	       contextInfo:contextObject];

	if (fd != -1) {
		unlink(templateFilename);
		close(fd);
		free(templateFilename);
	}

	return YES;
}

@end
