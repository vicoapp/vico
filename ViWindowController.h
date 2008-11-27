#import <Cocoa/Cocoa.h>
#import "ViTagStack.h"

@class PSMTabBarControl;
@class ViDocument;
@class ProjectDelegate;
@class ViResizeView;

@interface ViWindowController : NSWindowController
{
	IBOutlet PSMTabBarControl *tabBar;
	IBOutlet NSTabView *tabView;
	IBOutlet NSSplitView *splitView;
	IBOutlet NSOutlineView *projectOutline;
	IBOutlet NSToolbar *toolbar;
	IBOutlet ProjectDelegate *projectDelegate;
	IBOutlet NSImageView *projectResizeView;
	IBOutlet NSImageView *symbolsResizeView;
	IBOutlet NSView *symbolsView;
	IBOutlet NSSearchField *symbolFilterField;
	IBOutlet NSOutlineView *symbolsOutline;
	IBOutlet NSTreeController *symbolsController;
	ViTagStack *tagStack;
	BOOL isLoaded;
	ViDocument *initialDocument;
	ViDocument *lastDocument;
	NSMutableArray *filteredSymbols;
	NSMutableArray *documents;
}

@property(readwrite, assign) NSMutableArray *filteredSymbols;
@property(readwrite, assign) NSMutableArray *documents;

+ (id)currentWindowController;
+ (NSWindow *)currentMainWindow;

- (IBAction)saveProject:(id)sender;

- (void)addNewTab:(ViDocument *)document;

- (int)numberOfTabViewItems;
- (void)removeTabViewItemContainingDocument:(ViDocument *)doc;
- (NSTabViewItem *)tabViewItemForDocument:(ViDocument *)doc;
- (ViDocument *)currentDocument;
- (void)selectDocument:(ViDocument *)document;

- (ViTagStack *)sharedTagStack;

- (IBAction)selectTab:(id)sender;
- (IBAction)selectNextTab:(id)sender;
- (IBAction)selectPreviousTab:(id)sender;

- (void)switchToLastFile;

- (IBAction)filterSymbols:(id)sender;

@end

