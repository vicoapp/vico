#import "ViRegexp.h"
#import "ViBgView.h"

@class SFTPDirectoryEntry;

@interface ProjectFile : NSObject
{
	NSURL *url;
	SFTPDirectoryEntry *entry;
	double score;
	NSArray *children;
}
@property(readwrite, assign) double score;
@end

@interface ProjectDelegate : NSObject
{
	IBOutlet NSWindow *window;
	IBOutlet NSOutlineView *explorer;
	IBOutlet NSMenu *actionMenu;
	IBOutlet NSSearchField *filterField;
	IBOutlet NSSplitView *splitView;
	IBOutlet ViBgView *explorerView;
	IBOutlet NSWindow *sftpConnectView;
	IBOutlet NSForm *sftpConnectForm;
	IBOutlet NSScrollView *scrollView;
	IBOutlet NSPathControl *rootButton;

	NSMutableParagraphStyle *matchParagraphStyle;
	BOOL closeExplorerAfterUse;
	IBOutlet id delegate;
	NSArray *rootItems;
	NSMutableArray *filteredItems;
	ViRegexp *skipRegex;
}

@property(readwrite,assign) id delegate;

- (void)addURL:(NSURL *)aURL;
- (IBAction)addLocation:(id)sender;
- (IBAction)addSFTPLocation:(id)sender;
- (IBAction)actionMenu:(id)sender;

- (void)showExplorerSearch;
- (void)hideExplorerSearch;

- (IBAction)acceptSftpSheet:(id)sender;
- (IBAction)cancelSftpSheet:(id)sender;

- (IBAction)filterFiles:(id)sender;
- (IBAction)searchFiles:(id)sender;
- (IBAction)toggleExplorer:(id)sender;

@end
