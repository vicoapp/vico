#import "ViRegexp.h"
#import "ViBgView.h"
#import "ViToolbarPopUpButtonCell.h"
#import "ViOutlineView.h"
#import "ViSplitView.h"
#import "ViJumpList.h"

#include <CoreServices/CoreServices.h>

@class ViWindowController;
@class ExEnvironment;

@interface ProjectFile : NSObject
{
	NSURL *url;
	NSDictionary *attributes;
	double score;
	NSMutableArray *children;
	NSAttributedString *markedString;
}
@property(readwrite, assign) double score;
@property(readwrite, copy) NSURL *url;
@property(readwrite, assign) NSAttributedString *markedString;
@property(readwrite, assign) NSMutableArray *children;
- (BOOL)isDirectory;
- (BOOL)hasCachedChildren;
- (NSString *)name;
@end

@interface ProjectDelegate : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate, ViJumpListDelegate>
{
	IBOutlet NSWindow *window;
	IBOutlet ExEnvironment *environment;
	IBOutlet ViWindowController *windowController;
	IBOutlet ViOutlineView *explorer;
	IBOutlet NSMenu *actionMenu;
	IBOutlet NSSearchField *filterField;
	IBOutlet ViSplitView *splitView;
	IBOutlet ViBgView *explorerView;
	IBOutlet NSWindow *sftpConnectView;
	IBOutlet NSForm *sftpConnectForm;
	IBOutlet NSScrollView *scrollView;
	IBOutlet NSPathControl *rootButton;
	IBOutlet ViToolbarPopUpButtonCell *actionButtonCell;
	IBOutlet NSPopUpButton *actionButton;
	IBOutlet NSProgressIndicator *progressIndicator;

	NSFont *font;

	// file system events
	FSEventStreamRef evstream;

	// remembering expanded state
	NSMutableSet *expandedSet;

	// incremental file filtering
	NSMutableArray *filteredItems;
	NSMutableArray *itemsToFilter;
	ViRegexp *rx;

	BOOL closeExplorerAfterUse;
	IBOutlet id delegate;
	NSMutableArray *rootItems;
	ViRegexp *skipRegex;

	BOOL isFiltered;
	BOOL isFiltering;

	ViJumpList *history;
}

@property(readwrite,assign) id delegate;

- (void)browseURL:(NSURL *)aURL andDisplay:(BOOL)display;
- (void)browseURL:(NSURL *)aURL;
- (IBAction)addSFTPLocation:(id)sender;
- (IBAction)actionMenu:(id)sender;

- (IBAction)openInTab:(id)sender;
- (IBAction)openInCurrentView:(id)sender;
- (IBAction)openInSplit:(id)sender;
- (IBAction)openInVerticalSplit:(id)sender;
- (IBAction)renameFile:(id)sender;
- (IBAction)removeFiles:(id)sender;
- (IBAction)rescan:(id)sender;
- (IBAction)revealInFinder:(id)sender;
- (IBAction)openWithFinder:(id)sender;
- (IBAction)newFolder:(id)sender;
- (IBAction)newDocument:(id)sender;
- (IBAction)bookmarkFolder:(id)sender;
- (IBAction)gotoBookmark:(id)sender;

- (IBAction)acceptSftpSheet:(id)sender;
- (IBAction)cancelSftpSheet:(id)sender;

- (IBAction)filterFiles:(id)sender;
- (IBAction)searchFiles:(id)sender;
- (BOOL)explorerIsOpen;
- (void)openExplorerTemporarily:(BOOL)temporarily;
- (void)closeExplorer;
- (IBAction)focusExplorer:(id)sender;
- (IBAction)toggleExplorer:(id)sender;
- (void)cancelExplorer;
- (BOOL)isEditing;

@end
