#import <Cocoa/Cocoa.h>
#import "ViTagStack.h"

@class PSMTabBarControl;
@class ViDocument;

@interface ViWindowController : NSWindowController
{
	IBOutlet PSMTabBarControl *tabBar;
	IBOutlet NSTabView *tabView;
	IBOutlet NSSplitView *splitView;
	IBOutlet NSOutlineView *projectView;
	IBOutlet NSToolbar *toolbar;
	ViTagStack *tagStack;
	BOOL isLoaded;
	ViDocument *initialDocument;
	ViDocument *lastDocument;
}

+ (id)currentWindowController;
+ (NSWindow *)currentMainWindow;

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

