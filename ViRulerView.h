@interface ViRulerView : NSRulerView
{
	NSFont		*font;
	NSColor		*color;
	NSColor		*backgroundColor;
}

- (id)initWithScrollView:(NSScrollView *)aScrollView;

@end
