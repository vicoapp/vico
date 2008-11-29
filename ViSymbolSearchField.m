#import "ViSymbolSearchField.h"
#import "ViWindowController.h"

@implementation ViSymbolSearchField

- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector
{
	// proxy command to delegate (the ViWindowController)
	return [[self delegate] searchField:self doCommandBySelector:aSelector];
}

@end
