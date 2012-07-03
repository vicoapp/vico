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

#import "ViBufferedStream.h"

@interface ViTaskRunner : NSObject <NSStreamDelegate>
{
	NSTask			*_task;
	NSWindow		*_window;
	ViBufferedStream	*_stream;
	NSMutableData		*_stdout;
	NSMutableData		*_stderr;
	int			 _status;
	BOOL			 _done;
	BOOL			 _failed;
	BOOL			 _cancelled;
	id			 _target;
	SEL			 _selector;
	id			 _contextInfo;

	/* Blocking for completion. */
	IBOutlet NSWindow	*waitWindow; // Top-level nib object
	IBOutlet NSButton	*cancelButton;
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSTextField	*waitLabel;
}

@property (nonatomic, readwrite, retain) NSTask *task;
@property (nonatomic, readwrite, retain) NSWindow *window;
@property (nonatomic, readwrite, retain) ViBufferedStream *stream;
@property (nonatomic, readwrite, retain) NSMutableData *standardOutput;
@property (nonatomic, readwrite, retain) NSMutableData *standardError;
@property (nonatomic, readwrite, retain) id contextInfo;
@property (nonatomic, readwrite, retain) id target;
@property (nonatomic, readonly) int status;
@property (nonatomic, readonly) BOOL cancelled;

- (NSString *)stdoutString;

- (void)launchTask:(NSTask *)aTask
 withStandardInput:(NSData *)stdin
asynchronouslyInWindow:(NSWindow *)aWindow
	     title:(NSString *)displayTitle
	    target:(id)aTarget
	  selector:(SEL)aSelector
       contextInfo:(id)contextObject;

- (BOOL)launchShellCommand:(NSString *)shellCommand
	 withStandardInput:(NSData *)stdin
	       environment:(NSDictionary *)environment
	  currentDirectory:(NSString *)currentDirectory
    asynchronouslyInWindow:(NSWindow *)aWindow
		     title:(NSString *)displayTitle
		    target:(id)aTarget
		  selector:(SEL)aSelector
	       contextInfo:(id)contextObject
		     error:(NSError **)outError;

- (IBAction)cancelTask:(id)sender;

@end

