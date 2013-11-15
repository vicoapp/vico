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
//  Created by Paul Kim on 9/28/08.
//  Copyright (c) 2008 Noodlesoft, LLC. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

#import "ViRulerView.h"
#include "ViFold.h"
#import "ViTextView.h"
#import "ViThemeStore.h"
#import "NSObject+SPInvocationGrabbing.h"
#include "logging.h"

#define DEFAULT_THICKNESS   22.0
#define RULER_MARGIN        5.0

@implementation ViRulerView

- (id)initWithScrollView:(NSScrollView *)aScrollView
{
	if ((self = [super initWithScrollView:aScrollView orientation:NSVerticalRuler]) != nil) {
		[self setClientView:[[self scrollView] documentView]];
		_backgroundColor = [NSColor colorWithDeviceRed:(float)0xED/0xFF
							 green:(float)0xED/0xFF
							  blue:(float)0xED/0xFF
							 alpha:1.0];
		[self resetTextAttributes];
		_relative = NO;
	}
	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	for (int i = 0; i < 10; i++)
		;
}

- (void)setRelative:(BOOL)flag
{
	if (_relative != flag) {
		_relative = flag;

		[self setNeedsDisplay:YES];
	}
}

- (void)drawString:(NSString *)string intoImage:(NSImage *)image
{
	[image lockFocusFlipped:NO];
	[_backgroundColor set];
	NSRectFill(NSMakeRect(0, 0, _digitSize.width, _digitSize.height));
	[string drawAtPoint:NSMakePoint(0.5,0.5) withAttributes:_textAttributes];
	[image unlockFocus];
}

- (void)resetTextAttributes
{
	_textAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:
		[NSFont labelFontOfSize:0.8 * [[ViThemeStore font] pointSize]], NSFontAttributeName, 
		[NSColor colorWithCalibratedWhite:0.42 alpha:1.0], NSForegroundColorAttributeName,
		nil];

	_digitSize = [@"8" sizeWithAttributes:_textAttributes];
	_digitSize.width += 1.0;
	_digitSize.height += 1.0;

	[self setRuleThickness:[self requiredThickness]];

	for (int i = 0; i < 10; i++) {
		NSString *lineNumberString = [NSString stringWithFormat:@"%i", i];
		_digits[i] = [[NSImage alloc] initWithSize:_digitSize];

		[self drawString:lineNumberString intoImage:_digits[i]];
	}

	_closedFoldIndicator = [[NSImage alloc] initWithSize:_digitSize];
	[self drawString:@"-" intoImage:_closedFoldIndicator];
	_openFoldStartIndicator = [[NSImage alloc] initWithSize:_digitSize];
	[self drawString:@"o" intoImage:_openFoldStartIndicator];
	_openFoldBodyIndicator = [[NSImage alloc] initWithSize:_digitSize];
	[self drawString:@"|" intoImage:_openFoldBodyIndicator];

	[self setNeedsDisplay:YES];
}

- (void)setClientView:(NSView *)aView
{
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	id oldClientView = [self clientView];

	if (oldClientView != aView &&
	    [oldClientView isKindOfClass:[NSTextView class]]) {
		[notificationCenter removeObserver:self
					      name:ViTextStorageChangedLinesNotification
					    object:[(NSTextView *)oldClientView textStorage]];
		[notificationCenter removeObserver:self
					      name:ViCaretChangedNotification
					    object:oldClientView];
	}

	[super setClientView:aView];

	if (aView != nil && [aView isKindOfClass:[NSTextView class]]) {
		[notificationCenter addObserver:self
				       selector:@selector(textStorageDidChangeLines:)
					   name:ViTextStorageChangedLinesNotification
					 object:[(NSTextView *)aView textStorage]];
		[notificationCenter addObserver:self
				       selector:@selector(caretDidChange:)
					   name:ViCaretChangedNotification
					 object:aView];
	}
}

- (void)textStorageDidChangeLines:(NSNotification *)notification
{
	NSDictionary *userInfo = [notification userInfo];

	NSUInteger linesRemoved = [[userInfo objectForKey:@"linesRemoved"] unsignedIntegerValue];
	NSUInteger linesAdded = [[userInfo objectForKey:@"linesAdded"] unsignedIntegerValue];

	NSInteger diff = linesAdded - linesRemoved;
	if (diff == 0)
		return;

	[self setNeedsDisplay:YES];

	CGFloat thickness;
	thickness = [self requiredThickness];
	if (thickness != [self ruleThickness])
		[[self nextRunloop] setRuleThickness:thickness];
}

- (void)caretDidChange:(NSNotification *)notification
{
	if (_relative) {
		[self setNeedsDisplay:YES];
	}
}

- (CGFloat)requiredThickness
{
	NSUInteger	 lineCount, digits;

	id view = [self clientView];
	if ([view isKindOfClass:[ViTextView class]]) {
		lineCount = [[(ViTextView *)view textStorage] lineCount];
		digits = (unsigned)log10(lineCount) + 3;
		return ceilf(MAX(DEFAULT_THICKNESS, _digitSize.width * digits + RULER_MARGIN * 2));
	}

	return 0;
}

- (void)drawLineNumber:(NSInteger)line inRect:(NSRect)rect
{
	NSUInteger absoluteLine = ABS(line);

	do {
		NSUInteger rem = absoluteLine % 10;
		absoluteLine = absoluteLine / 10;

		rect.origin.x -= _digitSize.width;

		[_digits[rem] drawInRect:rect
				fromRect:NSZeroRect
			       operation:NSCompositeSourceOver
				fraction:1.0
			  respectFlipped:YES
				   hints:nil];
	} while (absoluteLine > 0);
}

- (void)drawFoldIndicator:(NSImage *)indicator inRect:(NSRect)rect
{
	[indicator drawInRect:rect
				 fromRect:NSZeroRect
				operation:NSCompositeSourceOver
				 fraction:1.0
		   respectFlipped:YES
					hints:nil];
}

- (void)drawHashMarksAndLabelsInRect:(NSRect)aRect
{
	NSRect bounds = [self bounds];

	[_backgroundColor set];
	NSRectFill(bounds);

	[[NSColor colorWithCalibratedWhite:0.58 alpha:1.0] set];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(NSMaxX(bounds) - 0.5, NSMinY(bounds))
				  toPoint:NSMakePoint(NSMaxX(bounds) - 0.5, NSMaxY(bounds))];

	id view = [self clientView];
	if (![view isKindOfClass:[ViTextView class]])
		return;

	ViTextView              *textView = (ViTextView *)view;
	ViDocument				*document = textView.document;
	NSLayoutManager         *layoutManager;
	NSTextContainer         *container;
	ViTextStorage		*textStorage;
	NSRect                  visibleRect;
	NSRange                 range, glyphRange;
	CGFloat                 ypos, yinset;

	layoutManager = [view layoutManager];
	container = [view textContainer];
	textStorage = [textView textStorage];
	yinset = [view textContainerInset].height;
	visibleRect = [[[self scrollView] contentView] bounds];

	if (layoutManager == nil)
		return;

	// Find the characters that are currently visible
	glyphRange = [layoutManager glyphRangeForBoundingRect:visibleRect
					      inTextContainer:container];
	range = [layoutManager characterRangeForGlyphRange:glyphRange
					  actualGlyphRange:NULL];

	NSUInteger line = [textStorage lineNumberAtLocation:range.location];
	NSUInteger location = range.location;

	if (location >= NSMaxRange(range)) {
		// Draw line number "0" in empty documents

		ypos = yinset - NSMinY(visibleRect);
		// Draw digits flush right, centered vertically within the line
		NSRect r;
		r.origin.x = NSWidth(bounds) - RULER_MARGIN;
		r.origin.y = ypos + 2.0;
		r.size = _digitSize;

		[self drawLineNumber:0 inRect:r];
		return;
	}

	NSUInteger currentLine = _relative ? [textView currentLine] : 0;
	for (; location < NSMaxRange(range); line++) {
		NSUInteger glyphIndex = [layoutManager glyphIndexForCharacterAtIndex:location];
		NSRect rect = [layoutManager lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:NULL];

		// Note that the ruler view is only as tall as the visible
		// portion. Need to compensate for the clipview's coordinates.
		ypos = yinset + NSMinY(rect) - NSMinY(visibleRect);

		// Draw digits flush right, centered vertically within the line
		NSRect r;
		r.origin.x = floor(NSWidth(bounds) - RULER_MARGIN);
		r.origin.y = floor(ypos + (NSHeight(rect) - _digitSize.height) / 2.0 + 1.0);
		r.size = _digitSize;

		NSUInteger numberToDraw = line;
		if (_relative)
			numberToDraw -= currentLine;
		[self drawLineNumber:numberToDraw inRect:r];

		ViFold *fold = [document foldAtLocation:location];
		if (fold) {
			NSLog(@"Found a fold at %lu; it says it starts at %lu", location, fold.range.location);
			NSImage *indicatorToDraw = _openFoldBodyIndicator;
			if (! fold.isOpen) {
			  indicatorToDraw = _closedFoldIndicator;
			} else if (fold.range.location == location) {
				indicatorToDraw = _openFoldStartIndicator;
			}

			NSRect indicatorRect;
			indicatorRect.origin.x = ceil(RULER_MARGIN);
			indicatorRect.origin.y = floor(ypos + (NSHeight(rect) - _digitSize.height) / 2.0 + 1.0);
			indicatorRect.size = _digitSize;

			[self drawFoldIndicator:indicatorToDraw inRect:indicatorRect];
		}

                /* Protect against an improbable (but possible due to
                 * preceeding exceptions in undo manager) out-of-bounds
                 * reference here.
		 */
		if (location >= [textStorage length]) {
			break;
		}
		[[textStorage string] getLineStart:NULL
					       end:&location
				       contentsEnd:NULL
					  forRange:NSMakeRange(location, 0)];
	}
}

- (void)mouseDown:(NSEvent *)theEvent
{
	id view = [self clientView];
	if ([view isKindOfClass:[ViTextView class]]) {
		_fromPoint = [view convertPoint:[theEvent locationInWindow] fromView:nil];
		_fromPoint.x = 0;
		[(ViTextView *)view rulerView:self selectFromPoint:_fromPoint toPoint:_fromPoint];
	}
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	id view = [self clientView];
	if ([view isKindOfClass:[ViTextView class]]) {
		NSPoint toPoint = [view convertPoint:[theEvent locationInWindow] fromView:nil];
		toPoint.x = 0;
		[(ViTextView *)view rulerView:self selectFromPoint:_fromPoint toPoint:toPoint];
	}
}

@end
