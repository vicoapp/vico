@interface ViRulerView : NSRulerView
{
	NSDictionary	*_textAttributes;
	NSColor		*_backgroundColor;
	NSPoint		 _fromPoint;
}

- (id)initWithScrollView:(NSScrollView *)aScrollView;
- (void)resetTextAttributes;

@end
