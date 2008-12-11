
@implementation NSTextField (additions)

- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector
{
	// proxy command to delegate
	return [[self delegate] textField:self doCommandBySelector:aSelector];
}

@end

