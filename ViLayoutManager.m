#import "ViLayoutManager.h"

@implementation ViLayoutManager

@synthesize invisiblesAttributes;

- (id)init
{
	self = [super init];
	if (self) {
		newlineChar = [NSString stringWithFormat:@"%C", 0x21A9];
		tabChar = [NSString stringWithFormat:@"%C", 0x21E5];
		//spaceChar = [NSString stringWithFormat:@"%C", 0x2423];
		spaceChar = [NSString stringWithFormat:@"%C", 0x302E];
	}
	return self;
}

- (void)drawGlyphsForGlyphRange:(NSRange)glyphRange atPoint:(NSPoint)containerOrigin
{
	if (showInvisibles) {
		NSString *completeString = [[self textStorage] string];
		NSUInteger lengthToRedraw = NSMaxRange(glyphRange);
		NSUInteger glyphIndex;

		for (glyphIndex = glyphRange.location; glyphIndex < lengthToRedraw; glyphIndex++) {
			NSUInteger charIndex = [self characterIndexForGlyphAtIndex:glyphIndex];
			unichar ch = [completeString characterAtIndex:charIndex];
			NSString *visibleChar = nil;

			switch (ch) {
			case '\n':
				visibleChar = newlineChar;
				break;
			case '\t':
				visibleChar = tabChar;
				break;
			case ' ':
				visibleChar = spaceChar;
				break;
			}

			if (visibleChar) {
				NSPoint pointToDrawAt = [self locationForGlyphAtIndex:glyphIndex];
				NSRect glyphFragment = [self lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:NULL];
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
