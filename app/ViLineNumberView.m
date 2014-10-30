#import "ViLineNumberView.h"

#import "ViFold.h"
#import "ViTextView.h"
#import "ViThemeStore.h"

#define DEFAULT_THICKNESS	22.0
#define LINE_NUMBER_MARGIN	5.0

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

@implementation ViLineNumberView

- (ViLineNumberView *)initWithTextView:(ViTextView *)aTextView backgroundColor:(NSColor *)aColor
{
	if (self = [super init]) {
		_backgroundColor = aColor;
		_relative = NO;

		self.autoresizingMask = NSViewMinXMargin | NSViewMaxXMargin;

		[self setTextView:aTextView];
		[self resetTextAttributes];
	}
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

// We override this because due to how we do drawing here, simply
// saying the line numbers need display isn't enough; we need to
// tell the ruler view it needs display as well.
- (void)setNeedsDisplay:(BOOL)needsDisplay
{
	[super setNeedsDisplay:needsDisplay];

	[[self superview] setNeedsDisplay:needsDisplay];
}

- (void)setRelative:(BOOL)flag
{
	if (_relative != flag) {
		_relative = flag;

		[[self superview] setNeedsDisplay:YES];
	}
}

- (void)setTextView:(ViTextView *)aTextView
{
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	if (_textView != aTextView) {
		[notificationCenter removeObserver:self
									  name:ViTextStorageChangedLinesNotification
									object:_textView.textStorage];
		[notificationCenter removeObserver:self
									  name:ViCaretChangedNotification
									object:_textView];
	}

	if (aTextView != nil) {
		[notificationCenter addObserver:self
							   selector:@selector(textStorageDidChangeLines:)
								   name:ViTextStorageChangedLinesNotification
								 object:_textView.textStorage];
		[notificationCenter addObserver:self
							   selector:@selector(caretDidChange:)
								   name:ViCaretChangedNotification
								 object:_textView];

		[notificationCenter addObserver:self
							   selector:@selector(foldsDidUpdate:)
								   name:ViFoldsChangedNotification
								 object:_textView.document];
		[notificationCenter addObserver:self
							   selector:@selector(foldsDidUpdate:)
								   name:ViFoldOpenedNotification
								 object:_textView.document];
		[notificationCenter addObserver:self
							   selector:@selector(foldsDidUpdate:)
								   name:ViFoldClosedNotification
								 object:_textView.document];
	}

	_textView = aTextView;
}

- (CGFloat)requiredThickness
{
	NSUInteger	 lineCount, digits;

	lineCount = _textView.viTextStorage.lineCount;
	digits = (unsigned)log10(lineCount) + 1;
	return ceilf(MAX(DEFAULT_THICKNESS, _digitSize.width * digits + LINE_NUMBER_MARGIN * 2));
}

- (void)updateViewFrame
{
	[self setFrameSize:NSMakeSize([self requiredThickness], _textView.bounds.size.height)];
}

#pragma mark -
#pragma mark String image initialization

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
	_textAttributes = @{
		NSFontAttributeName:			[NSFont labelFontOfSize:0.8 * [[ViThemeStore font] pointSize]],
		NSForegroundColorAttributeName:	[NSColor colorWithCalibratedWhite:0.42 alpha:1.0]
	};

	_digitSize = [@"8" sizeWithAttributes:_textAttributes];
	_digitSize.width += 1.0;
	_digitSize.height += 1.0;

	[self updateViewFrame];

	for (int i = 0; i < 10; i++) {
		NSString *lineNumberString = [NSString stringWithFormat:@"%i", i];
		_digits[i] = [[NSImage alloc] initWithSize:_digitSize];

		[self drawString:lineNumberString intoImage:_digits[i]];
	}

	[self setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark Notification handlers

- (void)textStorageDidChangeLines:(NSNotification *)notification
{
	NSDictionary *userInfo = [notification userInfo];

	NSUInteger linesRemoved = [[userInfo objectForKey:@"linesRemoved"] unsignedIntegerValue];
	NSUInteger linesAdded = [[userInfo objectForKey:@"linesAdded"] unsignedIntegerValue];

	NSInteger diff = linesAdded - linesRemoved;
	if (diff == 0)
		return;

	[self updateViewFrame];

	[self setNeedsDisplay:YES];
}

- (void)caretDidChange:(NSNotification *)notification
{
	if (_relative)
		[self setNeedsDisplay:YES];
}

- (void)foldsDidUpdate:(NSNotification *)notification
{
	[self setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark Line number drawing

- (void)drawLineNumber:(NSInteger)line inRect:(NSRect)rect
{
	NSUInteger absoluteLine = ABS(line);

	do {
		NSUInteger remainder = absoluteLine % 10;
		absoluteLine /= 10;

		rect.origin.x -= _digitSize.width;

		[_digits[remainder] drawInRect:rect
							  fromRect:NSZeroRect
							 operation:NSCompositeSourceOver
							  fraction:1.0
						respectFlipped:YES
								 hints:nil];
	} while (absoluteLine > 0);
}

- (NSInteger)logicalLineForLine:(NSUInteger)line location:(NSUInteger)location
{
	__block NSInteger logicalLine = line;
	
	if (location > 0) {
		ViTextStorage *textStorage = _textView.viTextStorage;
		[textStorage enumerateAttribute:ViFoldedAttributeName
								inRange:NSMakeRange(0u, location)
								options:NULL
							 usingBlock:^(ViFold *fold, NSRange foldedRange, BOOL *s) {
			 // Unfolded ranges don't affect the logical line.
			 if (! fold) return;
			 
			 // We go through each line in the folded range except the first one
			 // and subtract that line from the logical line. This makes each
			 // folded range count for one line.
			 NSUInteger currentLocation = NSMaxRange([textStorage rangeOfLineAtLocation:foldedRange.location]);
			 while (currentLocation < NSMaxRange(foldedRange) &&
					(currentLocation = NSMaxRange([textStorage rangeOfLineAtLocation:currentLocation + 1]))) {
				 logicalLine--;
			 }
		 }];
	}
	
	return logicalLine;
}

- (NSInteger)currentLogicalLine
{
	return [self logicalLineForLine:[_textView currentLine] location:[_textView caret]];
}

- (void)drawLineNumbersInRect:(NSRect)aRect visibleRect:(NSRect)visibleRect
{
	NSRect bounds = [self bounds];

	NSLayoutManager         *layoutManager;
	NSTextContainer         *container;
	ViTextStorage		*textStorage;
	NSRange                 range, glyphRange;
	CGFloat                 ypos, yinset;

	layoutManager = _textView.layoutManager;
	container = _textView.textContainer;
	textStorage = _textView.viTextStorage;
	yinset = _textView.textContainerInset.height;

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
		r.origin.x = NSWidth(bounds) - LINE_NUMBER_MARGIN;
		r.origin.y = ypos + 2.0;
		r.size = _digitSize;

		[self drawLineNumber:0 inRect:r];
		return;
	}

	NSUInteger logicalLine = [self logicalLineForLine:line location:location];
	NSInteger currentLogicalLine = _relative ? [self currentLogicalLine] : 0;
	for (; location < NSMaxRange(range); line++) {
		NSUInteger glyphIndex = [layoutManager glyphIndexForCharacterAtIndex:location];
		NSRect rect = [layoutManager lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:NULL];

		NSDictionary *attributesAtLineStart = [textStorage attributesAtIndex:location effectiveRange:NULL];

		if (! attributesAtLineStart[ViFoldedAttributeName]) {
			// Note that the ruler view is only as tall as the visible
			// portion. Need to compensate for the clipview's coordinates.
			ypos = yinset + NSMinY(rect) - NSMinY(visibleRect);

			// Draw digits flush right, centered vertically within the line
			NSRect r;
			r.origin.x = floor(NSWidth(bounds) - LINE_NUMBER_MARGIN);
			r.origin.y = floor(ypos + (NSHeight(rect) - _digitSize.height) / 2.0 + 1.0);
			r.size = _digitSize;

			NSInteger numberToDraw = _relative ? logicalLine - currentLogicalLine : line;
						
			[self drawLineNumber:numberToDraw inRect:r];
			
			logicalLine++;
		}

		/* Protect against an improbable (but possible due to
		 * preceeding exceptions in undo manager) out-of-bounds
		 * reference here.
		 */
		if (location >= [textStorage length]) {
			break;
		}

		[textStorage.string getLineStart:NULL
									 end:&location
							 contentsEnd:NULL
								forRange:NSMakeRange(location, 0)];
	}
}

#pragma mark -
#pragma mark Mouse handling

- (void)lineNumberMouseDown:(NSEvent *)theEvent
{
	_fromPoint = [_textView convertPoint:[theEvent locationInWindow] fromView:nil];
	_fromPoint.x = 0;
	[_textView rulerView:(NSRulerView *)[self superview] selectFromPoint:_fromPoint toPoint:_fromPoint];
}

- (void)lineNumberMouseDragged:(NSEvent *)theEvent
{
	NSPoint toPoint = [_textView convertPoint:[theEvent locationInWindow] fromView:nil];
	toPoint.x = 0;
	[_textView rulerView:(NSRulerView *)[self superview] selectFromPoint:_fromPoint toPoint:toPoint];
}

@end
