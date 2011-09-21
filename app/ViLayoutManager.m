#import "ViLayoutManager.h"
#include "logging.h"

@implementation ViLayoutManager

@synthesize invisiblesAttributes = _invisiblesAttributes;

- (id)init
{
	if ((self = [super init]) != nil) {
		_newlineChar = [[NSString stringWithFormat:@"%C", 0x21A9] retain];
		_tabChar = [[NSString stringWithFormat:@"%C", 0x21E5] retain];
		_spaceChar = [@"･" retain];
	}
	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	[_newlineChar release];
	[_tabChar release];
	[_spaceChar release];
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
			NSString *visibleChar = nil;

			switch (ch) {
			case '\n':
				visibleChar = _newlineChar;
				break;
			case '\t':
				visibleChar = _tabChar;
				break;
			case ' ':
				visibleChar = _spaceChar;
				break;
			}

			if (visibleChar) {
				NSPoint pointToDrawAt = [self locationForGlyphAtIndex:glyphIndex];
				NSRect glyphFragment = [self lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:NULL];
				pointToDrawAt.x += glyphFragment.origin.x;
				pointToDrawAt.y = glyphFragment.origin.y;
				[visibleChar drawAtPoint:pointToDrawAt withAttributes:_invisiblesAttributes];
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
