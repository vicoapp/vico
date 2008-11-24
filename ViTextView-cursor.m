#import "ViTextView.h"

@implementation ViTextView (cursor)

- (void)updateInsertionPointInRect:(NSRect)aRect
{
	NSLayoutManager *lm = [self layoutManager];
	NSRange rr = [lm glyphRangeForCharacterRange:NSMakeRange(caret, 1) actualCharacterRange:NULL];
	NSRect caretRect = [lm boundingRectForGlyphRange:rr inTextContainer:[self textContainer]];

	if (NSIntersectsRect(caretRect, aRect)) 
	{
		if (mode == ViInsertMode)
			caretRect.size.width = 2;
		else
		{
			unichar c = [[storage string] characterAtIndex:caret];
			if (c == '\t')
			{
				// place cursor at end of tab, like vi does
				caretRect.origin.x += caretRect.size.width - 7;
			}
			if (c == '\t' || c == '\n')
				caretRect.size.width = 7; // FIXME: adjust to chosen font, calculated from 'a' for example
		}
		[[theme caretColor] set];
		[[NSBezierPath bezierPathWithRect:caretRect] fill];
	}
}

- (void)drawViewBackgroundInRect:(NSRect)aRect
{
	[super drawViewBackgroundInRect:aRect];
	[self updateInsertionPointInRect:aRect];
}

- (BOOL)shouldDrawInsertionPoint;
{
	return NO;
}

@end

