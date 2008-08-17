#import <Cocoa/Cocoa.h>
#import "ViTextView.h"
#import "ViEditController.h"
#import "ViTagStack.h"

@interface MyDocument : NSDocument
{
	IBOutlet NSWindow *documentWindow;
	IBOutlet NSDrawer *projectDrawer;
	IBOutlet NSTabView *tabView;
	NSString *readContent;
	ViTagStack *tagStack;
}
- (void)changeTheme:(ViTheme *)theme;
- (ViEditController *)currentEditor;
- (NSWindow *)window;
- (void)closeCurrentTab;
- (ViEditController *)openFileInTab:(NSString *)path;
- (ViTagStack *)sharedTagStack;
- (void)selectNextTab;
- (void)selectPreviousTab;
- (void)selectTab:(int)tab;
- (void)selectTabViewItem:(NSTabViewItem *)anItem;

@end
