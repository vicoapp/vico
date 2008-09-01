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

	NSURL *initialFileURL;
	NSDate *initialFileModificationDate;
}
- (void)changeTheme:(ViTheme *)theme;
- (void)setPageGuide:(int)pageGuideValue;
- (ViEditController *)currentEditor;
- (NSWindow *)window;
- (void)closeCurrentTab;
- (ViEditController *)openFileInTab:(NSString *)path;
- (ViTagStack *)sharedTagStack;
- (void)selectNextTab;
- (void)selectPreviousTab;
- (void)selectTab:(int)tab;
- (IBAction)toggleProjectDrawer:(id)sender;

@end
