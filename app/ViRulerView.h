@interface ViRulerView : NSRulerView
{
        NSDictionary    *textAttributes;
	NSColor		*backgroundColor;
	NSPoint		 fromPoint;
}

- (id)initWithScrollView:(NSScrollView *)aScrollView;
- (void)resetTextAttributes;

@end
