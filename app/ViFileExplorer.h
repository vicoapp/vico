#import "ViRegexp.h"
#import "ViToolbarPopUpButtonCell.h"
#import "ViOutlineView.h"
#import "ViJumpList.h"
#import "ViFile.h"

#include <CoreServices/CoreServices.h>

@class ViWindowController;
@class ViBgView;

@interface ViFileExplorer : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate, ViJumpListDelegate, ViKeyManagerTarget, NSMenuDelegate>
{
	IBOutlet NSWindow		*window;
	IBOutlet ViWindowController	*windowController;
	IBOutlet ViOutlineView		*explorer;
	IBOutlet NSMenu			*actionMenu;
	IBOutlet NSSearchField		*filterField;
	IBOutlet NSSearchField		*altFilterField;
	IBOutlet NSSplitView		*splitView;
	IBOutlet ViBgView		*explorerView;
	IBOutlet NSWindow		*sftpConnectView;
	IBOutlet NSForm			*sftpConnectForm;
	IBOutlet NSScrollView		*scrollView;
	IBOutlet ViToolbarPopUpButtonCell *actionButtonCell;
	IBOutlet NSPopUpButton		*actionButton;
	IBOutlet NSProgressIndicator	*progressIndicator;
	IBOutlet NSToolbarItem		*searchToolbarItem;
	IBOutlet NSPathControl		*pathControl;
	IBOutlet id			 delegate;

	NSURL				*_rootURL;
	CGFloat				 _width;
	NSFont				*_font;

	// remembering expanded state
	NSMutableSet			*_expandedSet;
	BOOL				 _isExpandingTree;

	NSInteger			 _lastSelectedRow;

	// incremental file filtering
	NSMutableArray			*_filteredItems;
	NSMutableArray			*_itemsToFilter;
	ViRegexp			*_rx;

	BOOL				 _closeExplorerAfterUse;
	NSMutableArray			*_rootItems;
	ViRegexp			*_skipRegex;

	BOOL				 _isFiltered;
	BOOL				 _isFiltering;
	// BOOL				 _isHidingAltFilterField;

	ViJumpList			*_history;

	NSMutableDictionary		*_statusImages;

        /*
         * Since we can't pass an object through a void* contextInfo and
         * expect the object to survive garbage collection, store a strong
         * reference here.
         */
	NSMutableSet			*_contextObjects; // XXX: not needed without GC (but maybe with ARC in the future?)
}

@property(nonatomic,readwrite,assign) id delegate;
@property(nonatomic,readonly) ViOutlineView *outlineView;
@property(nonatomic,readonly) NSURL *rootURL;

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
- (IBAction)flushCache:(id)sender;

- (IBAction)acceptSftpSheet:(id)sender;
- (IBAction)cancelSftpSheet:(id)sender;

- (IBAction)filterFiles:(id)sender;
- (IBAction)searchFiles:(id)sender;
- (BOOL)explorerIsOpen;
- (void)openExplorerTemporarily:(BOOL)temporarily;
- (void)closeExplorerAndFocusEditor:(BOOL)focusEditor;
- (IBAction)focusExplorer:(id)sender;
- (IBAction)toggleExplorer:(id)sender;
- (void)cancelExplorer;
- (BOOL)isEditing;
- (BOOL)displaysURL:(NSURL *)aURL;
- (BOOL)selectItemWithURL:(NSURL *)aURL;

- (NSSet *)clickedURLs;
- (NSSet *)clickedFolderURLs;
- (NSSet *)clickedFiles;

@end
