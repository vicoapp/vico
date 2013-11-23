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
		_backgroundColor = [NSColor colorWithDeviceRed:(float)0xED/0xFF
							 green:(float)0xED/0xFF
							  blue:(float)0xED/0xFF
							 alpha:1.0];

		[self setClientView:[[self scrollView] documentView]];
	}

	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setRelativeLineNumbers:(BOOL)flag
{
	if (_lineNumberView)
		[_lineNumberView setRelative:flag];
}

- (void)lineViewBoundsDidChange:(NSNotification *)aNotification
{
	[self setRuleThickness:[_lineNumberView requiredThickness]];
}

- (void)resetTextAttributes
{
	[_lineNumberView resetTextAttributes];
}

#pragma mark -
#pragma mark NSRulerView interface

- (void)setClientView:(NSView *)aView
{
	[super setClientView:aView];

	if (aView != nil && [aView isKindOfClass:[ViTextView class]]) {
		if (_lineNumberView) {
			[_lineNumberView setTextView:(ViTextView *)aView];
		} else {
			_lineNumberView = [[ViLineNumberView alloc] initWithTextView:(ViTextView *)aView
														 backgroundColor:_backgroundColor];

			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(lineViewFrameDidChange:)
														 name:NSViewFrameDidChangeNotification
													   object:_lineNumberView];

			[self addSubview:_lineNumberView];

			[_lineNumberView updateViewFrame];
			[self setRuleThickness:[_lineNumberView requiredThickness]];
		}
	}
}

- (void)lineViewFrameDidChange:(NSNotification *)aNotification
{
	NSLog(@"Updating to %.2f", [_lineNumberView requiredThickness]);
	[self setRuleThickness:[_lineNumberView requiredThickness]];
	NSLog(@"Got to %.2f", [self ruleThickness]);
}

- (void)drawHashMarksAndLabelsInRect:(NSRect)aRect
{
	NSRect bounds = [self bounds];
	NSRect visibleRect = [[[self scrollView] contentView] bounds];

	[_backgroundColor set];
	NSRectFill(bounds);

	[[NSColor colorWithCalibratedWhite:0.58 alpha:1.0] set];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(NSMaxX(bounds) - 0.5, NSMinY(bounds))
				  toPoint:NSMakePoint(NSMaxX(bounds) - 0.5, NSMaxY(bounds))];

	[_lineNumberView drawLineNumbersInRect:aRect visibleRect:visibleRect];

	/*
		ViFold *fold = [document foldAtLocation:location];
		if (fold) {
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
	*/
}

@end
