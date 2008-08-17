#import <Cocoa/Cocoa.h>
#import "ViTextView.h"
#import "ViEditController.h"

@interface MyDocument : NSDocument
{
	IBOutlet NSDrawer *projectDrawer;
	IBOutlet NSTabView *tabView;
	NSString *readContent;
}
- (void)changeTheme:(ViTheme *)theme;
- (ViEditController *)currentEditor;
@end
