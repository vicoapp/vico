#import <Cocoa/Cocoa.h>
#import "ViTextView.h"

@interface MyDocument : NSDocument
{
	IBOutlet ViTextView *textView;
	IBOutlet NSTextField *statusbar;
	IBOutlet NSWindow *editWindow;
	NSString *readContent;
	SEL exCommandSelector;
}
- (IBAction)finishedExCommand:(id)sender;
- (void)changeTheme:(ViTheme *)theme;
- (void)message:(NSString *)fmt, ...;
- (void)getExCommandForTextView:(ViTextView *)aTextView selector:(SEL)aSelector;
@end
