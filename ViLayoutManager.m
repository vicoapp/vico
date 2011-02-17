#import "ViLayoutManager.h"

@implementation ViLayoutManager

@synthesize invisiblesAttributes;

- (void)drawGlyphsForGlyphRange:(NSRange)glyphRange atPoint:(NSPoint)containerOrigin
{
	if (showInvisibles) {
		NSString *completeString = [[self textStorage] string];
		NSUInteger lengthToRedraw = NSMaxRange(glyphRange);
		NSUInteger ndx;

		for (ndx = glyphRange.location; ndx < lengthToRedraw; ndx++) {
			unichar ch = [completeString characterAtIndex:ndx];
			NSString *visibleChar = nil;

			switch (ch) {
			case '\n':
				visibleChar = @"\u21A9";
				break;
			case '\t':
				visibleChar = @"\u21E5" ;
				break;
			case ' ':
				visibleChar = @"\u2423";
				break;
			}

			if (visibleChar) {
				NSPoint pointToDrawAt = [self locationForGlyphAtIndex:ndx];
				NSRect glyphFragment = [self lineFragmentRectForGlyphAtIndex:ndx effectiveRange:NULL];
				pointToDrawAt.x += glyphFragment.origin.x;
				pointToDrawAt.y = glyphFragment.origin.y;
				[visibleChar drawAtPoint:pointToDrawAt withAttributes:invisiblesAttributes];
			}
		}
	}

	[super drawGlyphsForGlyphRange:glyphRange atPoint:containerOrigin];
}

- (void)setShowsInvisibleCharacters:(BOOL)flag
{
	showInvisibles = flag;
}

- (BOOL)showsInvisibleCharacters
{
	return showInvisibles;
}

@end
