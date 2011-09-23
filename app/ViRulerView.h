@interface ViRulerView : NSRulerView
{
	NSDictionary		*_textAttributes;
	NSColor			*_backgroundColor;
	NSPoint			 _fromPoint;
	NSImage			*_digits[10];
	NSSize			 _digitSize;
}

- (id)initWithScrollView:(NSScrollView *)aScrollView;
- (void)resetTextAttributes;

@end
