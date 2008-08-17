//
//  ViEditController.m
//  vizard
//
//  Created by Martin Hedenfalk on 2008-03-21.
//  Copyright 2008 Martin Hedenfalk. All rights reserved.
//

#import "ViEditController.h"

@implementation ViEditController

- (id)initWithString:(NSString *)data
{
	self = [super init];
	if(self)
	{
		[NSBundle loadNibNamed:@"EditorView" owner:self];
		if(data)
			[[[textView textStorage] mutableString] setString:data];
		[textView initEditor];
		[textView setDelegate:self];
	}

	return self;
}

- (void)setDelegate:(id)aDelegate
{
	delegate = aDelegate;
}

- (NSView *)view
{
	return view;
}

- (void)setString:(NSString *)aString
{
	[[[textView textStorage] mutableString] setString:aString];
}

- (void)setFilename:(NSURL *)aURL
{
	fileURL = aURL;
	[textView setFilename:aURL];
	[textView highlightEverything];
}

- (NSURL *)fileURL
{
	return fileURL;
}

- (void)changeTheme:(ViTheme *)theme
{
	[textView setTheme:theme];
}

- (void)message:(NSString *)fmt, ...
{
	va_list ap;
	va_start(ap, fmt);
	NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
	va_end(ap);

	NSLog(@"message: [%@]", msg);
	[statusbar setStringValue:msg];
}

- (IBAction)finishedExCommand:(id)sender
{
	NSString *exCommand = [statusbar stringValue];
	NSLog(@"got ex command? [%@]", exCommand);
	[statusbar setStringValue:@""];
	[statusbar setEditable:NO];
	[[delegate window] makeFirstResponder:textView];
	[textView performSelector:exCommandSelector withObject:exCommand];
}

/* FIXME: should probably subclass NSTextField to disallow losing focus due to tabbing or clicking outside.
 * Should handle escape and ctrl-c.
 */
- (void)getExCommandForTextView:(ViTextView *)aTextView selector:(SEL)aSelector
{
	[statusbar setStringValue:@":"]; // FIXME: should not select the colon
	[statusbar setEditable:YES];
	[statusbar setDelegate:self];
	exCommandSelector = aSelector;
	[[delegate window] makeFirstResponder:statusbar];
}

- (NSUndoManager *)undoManager
{
	return [textView undoManager];
}

// returns the data to save
- (NSData *)saveData
{
	return [[[textView textStorage] string] dataUsingEncoding:NSUTF8StringEncoding];
}

- (void)save
{
	[delegate saveDocument:self];
}

- (void)newTab
{
	[delegate newTabWithURL:nil];
}

@end
