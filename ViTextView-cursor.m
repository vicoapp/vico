#import "ViTextView.h"

@implementation ViTextView (cursor)

- (void)updateInsertionPoint
{
	NSRange rr = [self selectedRange];
	rr.length = 0; // interested in the beginning of a selection
	NSTextContainer *tc = [self textContainer];
	NSLayoutManager *lm = [self layoutManager];
	rr = [lm glyphRangeForCharacterRange:rr actualCharacterRange:NULL];
	NSRect gr = [lm boundingRectForGlyphRange:rr inTextContainer:tc];
	//	NSPoint caret = [self convertPoint:gr.origin toView:nil];
	
	// now draw our insertion point behind the text
	//	NSRect caretRect = [self getInsertionPointRect];
	//	if(NSIntersectsRect(aRect, gr) ) 
	//if(NSPointInRect(caret, aRect))
	{
		[self drawInsertionPointInRect:gr color:[self insertionPointColor] turnedOn:YES];
	}
}

- (void)drawViewBackgroundInRect:(NSRect)aRect
{
	[super drawViewBackgroundInRect:aRect];
	[self updateInsertionPoint];
}

- (void)drawInsertionPointInRect:(NSRect)rect
			   color:(NSColor *)color
			turnedOn:(BOOL)flag
{
	if(flag)
        {
		[self setNeedsDisplayInRect:oldCaretRect];
		
#if 0
		NSPoint aPoint = NSMakePoint(rect.origin.x, rect.origin.y + rect.size.height / 2);
		int glyphIndex = [[self layoutManager] glyphIndexForPoint:aPoint
							  inTextContainer:[self textContainer]];
		NSRect glyphRect = [[self layoutManager] boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1)
								   inTextContainer:[self textContainer]];
		if(mode == ViInsertMode)
			rect.size.width = rect.size.height / 2;
		else
			rect.size.width = 2;

		if(glyphRect.size.width > 0 && glyphRect.size.width < rect.size.width)
			rect.size.width = glyphRect.size.width;
#else
		rect.size.width = mode == ViInsertMode ? 2 : 7;
#endif

		[color set];
		//[[NSBezierPath bezierPathWithRect:rect] fill];
		//[NSBezierPath fillRect:rect];
		//		NSRectFillUsingOperation(rect, NSCompositeXOR);
		NSRectFillUsingOperation(rect, NSCompositePlusDarker);

		oldCaretRect = rect;
        }
#if 0
	else
        {
		[self setNeedsDisplayInRect:[self visibleRect]
		      avoidAdditionalLayout:NO];
        }
#endif
}

- (BOOL)shouldDrawInsertionPoint;
{
	return YES;
}

@end
