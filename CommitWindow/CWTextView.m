//
//  CWTextView.m
//  CommitWindow
//
//  Created by Chris Thomas on 3/7/05.
//  Copyright 2005-2006 Chris Thomas. All rights reserved.
//  MIT license.
//

#import "CWTextView.h"

@implementation CWTextView

- (void) awakeFromNib
{
	// Arbitrary factory settings
	fMinHeight	= 40.0f;
	fMaxHeight	= 32767.0f;
	fMinWidth	= 100.0f;
	fMaxWidth	= 32767.0f;
	
	fAllowGrowHorizontally	= NO;
	fAllowGrowVertically	= YES;
}

#if 0
#pragma mark -
#pragma mark Do not eat the enter key
#endif

- (void) keyDown:(NSEvent *)event
{
	// don't let the textview eat the enter key
	if( [[event characters] isEqualToString:@"\x03"] )
	{
		[[self nextResponder] keyDown:event];
	}
	else
	{
		[super keyDown:event];
	}
}

#if 0
#pragma mark -
#pragma mark Resize box
#endif

- (NSRect) growBoxRect
{
	NSRect	bounds		= [self bounds];
	NSRect	growBoxRect;
	
	growBoxRect.size.width	= 16;
	growBoxRect.size.height = 16;
	growBoxRect.origin.y	= NSMaxY(bounds) - growBoxRect.size.height;
	growBoxRect.origin.x	= NSMaxX(bounds) - growBoxRect.size.width;

	return growBoxRect;
}

- (void) drawRect:(NSRect)rect
{
//	NSRect	bounds		= [self bounds];
	NSRect	growBoxRect = [self growBoxRect];
	
	[super drawRect:rect];
	
	if( NSContainsRect(rect, growBoxRect) )
	{
		[NSGraphicsContext saveGraphicsState];
			[[NSColor darkGrayColor] set];
			
			[NSBezierPath clipRect:NSInsetRect(growBoxRect, 1, 1)];

			[NSBezierPath strokeLineFromPoint:NSMakePoint(growBoxRect.origin.x, growBoxRect.origin.y + 20 )
									  toPoint:NSMakePoint(growBoxRect.origin.x + 20, growBoxRect.origin.y)];
			[NSBezierPath strokeLineFromPoint:NSMakePoint(growBoxRect.origin.x, growBoxRect.origin.y + 24)
									  toPoint:NSMakePoint(growBoxRect.origin.x + 24, growBoxRect.origin.y)];
			[NSBezierPath strokeLineFromPoint:NSMakePoint(growBoxRect.origin.x, growBoxRect.origin.y + 28)
									  toPoint:NSMakePoint(growBoxRect.origin.x + 28, growBoxRect.origin.y)];
		[NSGraphicsContext restoreGraphicsState];
	}
	
}

- (void) mouseDown:(NSEvent *)event
{
	NSPoint locationInWindow	= [event locationInWindow];
	NSPoint	locationInView		= [self convertPoint:locationInWindow fromView:nil];
	NSRect	growBoxRect			= [self growBoxRect];
	
	if( NSMouseInRect(locationInView, growBoxRect, YES) )
	{
		fInitialViewFrame	= [[self enclosingScrollView] frame];
		fInitialMousePoint	= locationInWindow;
		fTrackingGrowBox	= YES;
	}
	else
	{
		[super mouseDown:event];
	}
}

- (void) mouseUp:(NSEvent *)event
{
	if(fTrackingGrowBox)
	{
		fTrackingGrowBox = NO;
	}
	else
	{
		[super mouseUp:event];
	}
}

- (void) mouseDragged:(NSEvent *)event
{
	NSPoint	currentPoint = [event locationInWindow];//[self convertPoint: fromView:nil];

	if(fTrackingGrowBox)
	{
		NSScrollView *	scrollView		= [self enclosingScrollView];
		NSRect			scrollFrame		= [scrollView frame];
		NSRect			newFrame		= scrollFrame;
		float			deltaY;
		
		// Horizontal
		if( fAllowGrowHorizontally )
		{
			newFrame.size.width = fInitialViewFrame.size.width + (currentPoint.x - fInitialMousePoint.x);
			if(newFrame.size.width < fMinWidth )
			{
				newFrame.size.width = fMinWidth;
			}
			else if(newFrame.size.width > fMaxWidth )
			{
				newFrame.size.width = fMaxWidth;
			}
		}
		
		// Vertical (FIXME: assumes the scroll view's superview is _not_ flipped)
		if( fAllowGrowVertically )
		{
			deltaY = currentPoint.y - fInitialMousePoint.y;
			newFrame.size.height = fInitialViewFrame.size.height - deltaY;

			// Check size
			if(newFrame.size.height < fMinHeight )
			{
				newFrame.size.height = fMinHeight;
			}
			else if(newFrame.size.height > fMaxHeight )
			{
				newFrame.size.height = fMaxHeight;			
			}

			// Adjust origin of frame
			newFrame.origin.y += scrollFrame.size.height - newFrame.size.height;
		}
		
		[scrollView setNeedsDisplayInRect:[scrollView bounds]];
		[scrollView setFrame:newFrame];
		[[NSCursor arrowCursor] set];
	}
	else
	{
		[super mouseDragged:event];
	}
}

// This alone is not enough -- see mouseMoved: below -- but it does cause the arrow to be correctly displayed during resize
- (void) resetCursorRects
{
	[super resetCursorRects];
	[self addCursorRect:[self growBoxRect] cursor:[NSCursor arrowCursor]];
}

// Required to override NSTextView's setting of the cursor during mouseMoved events
- (void) mouseMoved:(NSEvent *)event
{
	NSPoint locationInWindow	= [event locationInWindow];
	NSPoint	locationInView		= [self convertPoint:locationInWindow fromView:nil];
	NSRect	growBoxRect			= [self growBoxRect];
	
	if( NSMouseInRect(locationInView, growBoxRect, YES) )
	{
		[[NSCursor arrowCursor] set];
	}
	else
	{
		[super mouseMoved:event];
	}
}

#if 0
#pragma mark -
#pragma mark Simple accessors
#endif

// Grow planes

- (BOOL)allowHorizontalResize
{
	return fAllowGrowHorizontally;
}

- (void)setAllowHorizontalResize:(BOOL)newAllowGrowHorizontally
{
	fAllowGrowHorizontally = newAllowGrowHorizontally;
}

- (BOOL)allowVerticalResize
{
	return fAllowGrowVertically;
}

- (void)setAllowVerticalResize:(BOOL)newAllowGrowVertically
{
	fAllowGrowVertically = newAllowGrowVertically;
}

// Geometry

- (float)maxWidth
{
	return fMaxWidth;
}

- (void)setMaxWidth:(float)newMaxWidth
{
	fMaxWidth = newMaxWidth;
}

- (float)minWidth
{
	return fMinWidth;
}

- (void)setMinWidth:(float)newMinWidth
{
	fMinWidth = newMinWidth;
}

- (float)minHeight
{
	return fMinHeight;
}

- (void)setMinHeight:(float)newMinHeight
{
	fMinHeight = newMinHeight;
}

- (float)maxHeight
{
	return fMaxHeight;
}

- (void)setMaxHeight:(float)newMaxHeight
{
	fMaxHeight = newMaxHeight;
}


@end
