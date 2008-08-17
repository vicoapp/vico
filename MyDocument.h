#import <Cocoa/Cocoa.h>
#import "ViTextView.h"
#import "ViEditController.h"

@interface MyDocument : NSDocument
{
	IBOutlet NSWindow *documentWindow;
	IBOutlet NSDrawer *projectDrawer;
	IBOutlet NSTabView *tabView;
	NSString *readContent;
}
- (void)changeTheme:(ViTheme *)theme;
- (ViEditController *)currentEditor;
- (NSWindow *)window;
- (void)closeCurrentTab;
- (void)openFile:(NSString *)path;

@end
