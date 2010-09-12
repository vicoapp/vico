#import "ViCommandField.h"
#import "ViWindowController.h"

@implementation ViCommandField

- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector
{
	// proxy command to delegate
	if ([[self delegate] respondsToSelector:@selector(textField:doCommandBySelector:)])
		return [[self delegate] textField:self doCommandBySelector:aSelector];
	return [super textView:aTextView doCommandBySelector:aSelector];
}

@end

