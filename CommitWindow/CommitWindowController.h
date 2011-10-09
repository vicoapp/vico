//
//  CommitWindowController.h
//
//  Created by Chris Thomas on 2/6/05.
//  Copyright 2005 Chris Thomas. All rights reserved.
//	MIT license.
//

#import <Cocoa/Cocoa.h>

@class CWTextView;
@class CXMenuButton;

@interface CommitWindowController : NSWindowController <NSMenuDelegate>
{
//	NSMutableArray *	fFiles;		// {@"commit", @"path"}
	IBOutlet NSArrayController *	fFilesController;

	IBOutlet NSWindow *				fWindow;

	IBOutlet NSTextField *			fRequestText;
	IBOutlet CWTextView *			fCommitMessage;
	IBOutlet NSPopUpButton *		fPreviousSummaryPopUp;
	IBOutlet CXMenuButton *			fFileListActionPopUp;

	IBOutlet NSButton *				fCancelButton;
	IBOutlet NSButton *				fOKButton;

	IBOutlet NSTableView *			fTableView;
	IBOutlet NSTableColumn *		fCheckBoxColumn;
	IBOutlet NSTableColumn *		fStatusColumn;
	IBOutlet NSTableColumn *		fPathColumn;

	IBOutlet NSScrollView *			fSummaryScrollView;
	NSRect							fPreviousSummaryFrame;
	IBOutlet NSView *				fLowerControlsView;

	NSString *						fDiffCommand;
	NSMutableDictionary *			fActionCommands;
	
	NSArray *						fFileStatusStrings;
}

- (void) addAction:(NSString *)name command:(NSArray *)arguments forStatus:(NSString *)statusString;
- (void) setupUserInterface;
- (void) resetStatusColumnSize;

- (void) saveSummary;

- (IBAction) chooseAllFiles:(id)sender;
- (IBAction) chooseNoFiles:(id)sender;
- (IBAction) revertToStandardChosenState:(id)sender;

- (NSString *) absolutePathForPath:(NSString *)path;
- (void) checkExitStatus:(int)exitStatus forCommand:(NSArray *)arguments errorText:(NSString *)errorText;

@end
