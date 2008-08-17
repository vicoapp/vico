//
//  ViEditController.m
//  vizard
//
//  Created by Martin Hedenfalk on 2008-03-21.
//  Copyright 2008 Martin Hedenfalk. All rights reserved.
//

#import "ViEditController.h"
#import "MyDocument.h"

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
	if(!textViewConfigured)
	{
		[textView configureForURL:aURL];
		textViewConfigured = YES;
	}
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

	[statusbar setStringValue:msg];
}

- (IBAction)finishedExCommand:(id)sender
{
	NSString *exCommand = [statusbar stringValue];
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

- (ViEditController *)openFileInTab:(NSString *)path
{
	return [delegate openFileInTab:path];
}

- (BOOL)findPattern:(NSString *)pattern
	    options:(unsigned)find_options
         regexpType:(OgreSyntax)regexpSyntax
   ignoreLastRegexp:(BOOL)ignoreLastRegexp
{
	return [textView findPattern:pattern options:find_options regexpType:regexpSyntax ignoreLastRegexp:ignoreLastRegexp];
}

// tag push
- (void)pushLine:(NSUInteger)aLine column:(NSUInteger)aColumn
{
	[[delegate sharedTagStack] pushFile:[[self fileURL] path] line:aLine column:aColumn];
}

- (void)popTag
{
	NSDictionary *location = [[delegate sharedTagStack] pop];
	if(location == nil)
	{
		[self message:@"The tags stack is empty"];
		return;
	}

	NSLog(@"Jump to [%@] at line %u, col %u",
	      [location objectForKey:@"file"],
	      [[location objectForKey:@"line"] unsignedIntegerValue],
	      [[location objectForKey:@"column"] unsignedIntegerValue]);

	ViEditController *editor = [self openFileInTab:[location objectForKey:@"file"]];
	if(editor)
	{
		[[editor textView] gotoLine:[[location objectForKey:@"line"] unsignedIntegerValue]
				     column:[[location objectForKey:@"column"] unsignedIntegerValue]];
	}
}

- (ViTextView *)textView
{
	return textView;
}

- (void)selectNextTab
{
	[delegate selectNextTab];
}

- (void)selectPreviousTab
{
	[delegate selectPreviousTab];
}

- (void)selectTab:(int)tab
{
	[delegate selectTab:tab];
}

@end
