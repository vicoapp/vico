#import <Cocoa/Cocoa.h>
#import "ViTagStack.h"

@class PSMTabBarControl;
@class ViDocument;

@interface ViWindowController : NSWindowController
{
	IBOutlet PSMTabBarControl *tabBar;
	IBOutlet NSTabView *tabView;
	IBOutlet NSDrawer *projectDrawer;
	ViTagStack *tagStack;
	BOOL isLoaded;
	ViDocument *initialDocument;
}

+ (id)currentWindowController;
+ (NSWindow *)currentMainWindow;

- (void)addNewTab:(ViDocument *)document;

- (int)numberOfTabViewItems;
- (void)removeTabViewItemContainingDocument:(ViDocument *)doc;
- (NSTabViewItem *)tabViewItemForDocument:(ViDocument *)doc;
- (void)closeCurrentTabViewItem;
- (ViDocument *)currentDocument;
- (void)selectDocument:(ViDocument *)document;

- (ViTagStack *)sharedTagStack;
- (void)selectTab:(int)tab;
- (void)selectNextTab;
- (void)selectPreviousTab;
- (IBAction)toggleProjectDrawer:(id)sender;

@end

