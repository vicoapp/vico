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
 *

#import "ViRulerView.h"
#include "ViFold.h"
#import "ViTextView.h"
#import "ViThemeStore.h"
//#import "NSObect+SPInvocationGrabbing.h"
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
													 selector:@selector(subviewFrameDidChange:)
														 name:NSViewFrameDidChangeNotification
													   object:_lineNumberView];

			[self addSubview:_lineNumberView];
			[_lineNumberView updateViewFrame];
		}

		if (_foldMarginView) {
			[_foldMarginView setTextView:(ViTextView *)aView];
		} else {
			_foldMarginView = [[ViFoldMarginView alloc] initWithTextView:(ViTextView *)aView];

			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(subviewFrameDidChange:)
														 name:NSViewFrameDidChangeNotification
													   object:_foldMarginView];

			[self addSubview:_foldMarginView];
			[_foldMarginView updateViewFrame];
		}

		[self updateRuleThickness];
	}
}

- (void)subviewFrameDidChange:(NSNotification *)aNotification
{
	[self updateRuleThickness];
}

- (void)updateRuleThickness
{
	CGFloat newThickness = _lineNumberView.frame.size.width + _foldMarginView.frame.size.width;
	
	if (newThickness != [self ruleThickness]) {
		[[self nextRunloop] setRuleThickness:newThickness];
	}
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
	[_foldMarginView drawFoldsInRect:aRect visibleRect:visibleRect];
}

#pragma mark -
#pragma mark Mouse handling

- (void)mouseUp:(NSEvent *)theEvent
{
	NSPoint upPoint = [self convertPoint:theEvent.locationInWindow fromView:nil];
	if (upPoint.x > _lineNumberView.frame.size.width) {
		[_foldMarginView foldMarginMouseUp:theEvent];
	}
}

- (void)mouseDown:(NSEvent *)theEvent
{
	NSPoint downPoint = [self convertPoint:theEvent.locationInWindow fromView:nil];
	if (downPoint.x <= _lineNumberView.frame.size.width) {
		[_lineNumberView lineNumberMouseDown:theEvent];
	}
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	NSPoint dragPoint = [self convertPoint:theEvent.locationInWindow fromView:nil];
	if (dragPoint.x <= _lineNumberView.frame.size.width) {
		[_lineNumberView lineNumberMouseDragged:theEvent];
	}
}

@end
 */
