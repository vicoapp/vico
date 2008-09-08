//
//  ViEditController.h
//  vizard
//
//  Created by Martin Hedenfalk on 2008-03-21.
//  Copyright 2008 Martin Hedenfalk. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ViTextView.h"

@interface ViEditController : NSObject
{
	IBOutlet NSView *view;
	IBOutlet ViTextView *textView;
	IBOutlet NSTextField *statusbar;
	SEL exCommandSelector;
	id delegate;
	NSURL *fileURL;
	BOOL textViewConfigured;
	NSDate *last_mtime;
}

- (NSView *)view;
- (void)setDelegate:(id)aDelegate;
- (id)delegate;
- (void)setFileURL:(NSURL *)aURL;
- (NSURL *)fileURL;
- (void)setString:(NSString *)aString;
- (IBAction)finishedExCommand:(id)sender;
- (void)message:(NSString *)fmt, ...;
- (void)getExCommandForTextView:(ViTextView *)aTextView selector:(SEL)aSelector;
- (NSUndoManager *)undoManager;
- (NSData *)saveData;
- (void)changeTheme:(ViTheme *)theme;
- (void)setPageGuide:(int)pageGuideValue;
- (void)save;
- (ViEditController *)openFileInTab:(NSString *)path;
- (BOOL)findPattern:(NSString *)pattern
	    options:(unsigned)find_options
         regexpType:(OgreSyntax)regexpSyntax
   ignoreLastRegexp:(BOOL)ignoreLastRegexp;
- (void)pushLine:(NSUInteger)aLine column:(NSUInteger)aColumn;
- (void)popTag;


- (ViTextView *)textView;

- (void)selectNextTab;
- (void)selectPreviousTab;
- (void)selectTab:(int)tab;

- (NSDate *)fileModificationDate;
- (void)setFileModificationDate:(NSDate *)modificationDate;


@end
