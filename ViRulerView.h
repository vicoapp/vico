@interface ViRulerView : NSRulerView
{
	NSFont		*font;
	NSColor		*color;
	NSColor		*backgroundColor;
	NSPoint		 fromPoint;
}

- (id)initWithScrollView:(NSScrollView *)aScrollView;

@end
