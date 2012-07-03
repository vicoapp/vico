/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ViLayoutManager.h"
#import "ViThemeStore.h"
#include "logging.h"

@implementation ViLayoutManager

@synthesize invisiblesAttributes = _invisiblesAttributes;

- (void)setInvisiblesAttributes:(NSDictionary *)attributes
{
	[attributes retain];
	[_invisiblesAttributes release];
	_invisiblesAttributes = [attributes mutableCopy];
	[attributes release];

	[_invisiblesAttributes setObject:[ViThemeStore font] forKey:NSFontAttributeName];

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

DEBUG_FINALIZE();

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
