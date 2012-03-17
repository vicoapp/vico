/*
 *  Copyright (C) 2009 Stephen F. Booth <me@sbooth.org>
 *  All Rights Reserved
 */

#import <Cocoa/Cocoa.h>

// ========================================
// The main class for SFBCrashReporter
// ========================================
@interface SFBCrashReporterWindowController : NSWindowController
{
	IBOutlet NSTextView *_commentsTextView;
	IBOutlet NSButton *_reportButton;
	IBOutlet NSButton *_ignoreButton;
	IBOutlet NSButton *_discardButton;
	IBOutlet NSProgressIndicator *_progressIndicator;
	
@private
	NSString *_emailAddress;
	NSString *_crashLogPath;
	NSURL *_submissionURL;
	
	NSURLConnection *_urlConnection;
	NSMutableData *_responseData;
}

// ========================================
// Properties
@property (copy) NSString * emailAddress;
@property (copy) NSString * crashLogPath;
@property (copy) NSURL * submissionURL;

// ========================================
// Always use this to show the window- do not alloc/init directly
+ (void) showWindowForCrashLogPath:(NSString *)path submissionURL:(NSURL *)submissionURL;

// ========================================
// Action methods
- (IBAction) sendReport:(id)sender;
- (IBAction) ignoreReport:(id)sender;
- (IBAction) discardReport:(id)sender;

@end
