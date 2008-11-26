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
	ViTagStack *tagStack;
	BOOL isLoaded;
	ViDocument *initialDocument;
	ViDocument *lastDocument;
}

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
- (IBAction)toggleProjectDrawer:(id)sender;

- (void)switchToLastFile;

@end

