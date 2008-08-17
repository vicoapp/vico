#import <Cocoa/Cocoa.h>
#import "ViTextView.h"

@interface MyDocument : NSDocument
{
	IBOutlet ViTextView *textView;
	IBOutlet NSTextField *statusbar;
	NSString *readContent;
}
- (void)changeTheme:(ViTheme *)theme;
@end
