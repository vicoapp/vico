#import "ViLayoutManager.h"
#include "logging.h"

@implementation ViLayoutManager

@synthesize invisiblesAttributes = _invisiblesAttributes;

- (void)setInvisiblesAttributes:(NSDictionary *)attributes
{
	[attributes retain];
	[_invisiblesAttributes release];
	_invisiblesAttributes = attributes;

	NSString *newlineChar = [NSString stringWithFormat:@"%C", 0x21A9];
	NSString *tabChar = [NSString stringWithFormat:@"%C", 0x21E5];
	NSString *spaceChar = @"･";

	[_newlineImage release];
	[_tabImage release];
	[_spaceImage release];

	NSSize sz = [newlineChar sizeWithAttributes:_invisiblesAttributes];
	_newlineImage = [[NSImage alloc] initWithSize:sz];
	[_newlineImage lockFocusFlipped:NO];
	[newlineChar drawAtPoint:NSMakePoint(0,0) withAttributes:_invisiblesAttributes];
	[_newlineImage unlockFocus];

	sz = [tabChar sizeWithAttributes:_invisiblesAttributes];
	_tabImage = [[NSImage alloc] initWithSize:sz];
	[_tabImage lockFocusFlipped:NO];
	[tabChar drawAtPoint:NSMakePoint(0,0) withAttributes:_invisiblesAttributes];
	[_tabImage unlockFocus];

	sz = [spaceChar sizeWithAttributes:_invisiblesAttributes];
	_spaceImage = [[NSImage alloc] initWithSize:sz];
	[_spaceImage lockFocusFlipped:NO];
	[spaceChar drawAtPoint:NSMakePoint(0,0) withAttributes:_invisiblesAttributes];
	[_spaceImage unlockFocus];

}

- (void)dealloc
{
	DEBUG_DEALLOC();
	[_newlineImage release];
	[_tabImage release];
	[_spaceImage release];
	[_invisiblesAttributes release];
	[super dealloc];
}

- (void)drawGlyphsForGlyphRange:(NSRange)glyphRange atPoint:(NSPoint)containerOrigin
{
	if (_showInvisibles) {
		NSString *completeString = [[self textStorage] string];
		NSUInteger lengthToRedraw = NSMaxRange(glyphRange);
		NSUInteger glyphIndex;

		for (glyphIndex = glyphRange.location; glyphIndex < lengthToRedraw; glyphIndex++) {
			NSUInteger charIndex = [self characterIndexForGlyphAtIndex:glyphIndex];
			unichar ch = [completeString characterAtIndex:charIndex];
			NSImage *visibleImage = nil;

			switch (ch) {
			case '\n':
				visibleImage = _newlineImage;
				break;
			case '\t':
				visibleImage = _tabImage;
				break;
			case ' ':
				visibleImage = _spaceImage;
				break;
			}

			if (visibleImage) {
				NSRect r;
				r.origin = [self locationForGlyphAtIndex:glyphIndex];
				NSRect glyphFragment = [self lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:NULL];
				r.origin.x += glyphFragment.origin.x;
				r.origin.y = glyphFragment.origin.y;
				r.size = [visibleImage size];
				[visibleImage drawInRect:r
						fromRect:NSZeroRect
					       operation:NSCompositeSourceOver
						fraction:1.0
					  respectFlipped:YES
						   hints:nil];
			}
		}
	}

	[super drawGlyphsForGlyphRange:glyphRange atPoint:containerOrigin];
}

- (void)setShowsInvisibleCharacters:(BOOL)flag
{
	_showInvisibles = flag;
}

- (BOOL)showsInvisibleCharacters
{
	return _showInvisibles;
}

@end
