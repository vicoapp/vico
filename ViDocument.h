#import <Cocoa/Cocoa.h>
#import "ViTextView.h"
#import "ViWindowController.h"

@interface ViDocument : NSDocument
{
	IBOutlet NSView *view;
	IBOutlet ViTextView *textView;
	IBOutlet NSTextField *statusbar;
	SEL exCommandSelector;
	ViWindowController *windowController;
	NSString *readContent;
}

- (NSView *)view;
- (IBAction)finishedExCommand:(id)sender;
- (void)message:(NSString *)fmt, ...;
- (void)getExCommandForTextView:(ViTextView *)aTextView selector:(SEL)aSelector;
- (void)changeTheme:(ViTheme *)theme;
- (void)setPageGuide:(int)pageGuideValue;
- (BOOL)findPattern:(NSString *)pattern
	    options:(unsigned)find_options
         regexpType:(OgreSyntax)regexpSyntax
   ignoreLastRegexp:(BOOL)ignoreLastRegexp;
- (void)pushLine:(NSUInteger)aLine column:(NSUInteger)aColumn;
- (void)popTag;
- (ViTextView *)textView;

@end

