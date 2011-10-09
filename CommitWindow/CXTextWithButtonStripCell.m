//
//  CXTextWithButtonStripCell.m
//  NSCell supporting row action buttons aligned to one side of a text table column.
//
//  Created by Chris Thomas on 2006-10-11.
//  Copyright 2006 Chris Thomas. All rights reserved.
//

#import "CXTextWithButtonStripCell.h"
#import "CXShading.h"

#define kVerticalMargin							1.0
#define kHorizontalMargin						2.0
#define kMarginBetweenTextAndButtons			8.0
#define kIconButtonWidth						16.0
#define kButtonInteriorVerticalEdgeMargin		8.0



@interface NSBezierPath (CXBezierPathAdditions)
+ (NSBezierPath*)bezierPathWithCapsuleRect:(NSRect)rect;
@end

@implementation NSBezierPath (CXBezierPathAdditions)

+ (NSBezierPath*)bezierPathWithCapsuleRect:(NSRect)rect
{
	NSBezierPath	*	path = [self bezierPath];
	float				radius = 0.5f * MIN(NSWidth(rect), NSHeight(rect));

	rect = NSInsetRect(rect, radius, radius);

	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect), NSMidY(rect)) radius:radius startAngle:90.0 endAngle:270.0];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(rect), NSMidY(rect)) radius:radius startAngle:270.0 endAngle:90.0];
	[path closePath];
	return path;
}

@end

@interface CXTextWithButtonStripCell (Private)
- (NSDictionary *) titleTextAttributes;
@end

@implementation CXTextWithButtonStripCell

// NSTableView frequently wants to make copies of the cell. Retain anything that later will be released.
- (id)copyWithZone:(NSZone *)zone
{
	CXTextWithButtonStripCell *	copiedCell = [super copyWithZone:zone];
	
	[copiedCell->fButtons retain];
	return copiedCell;
}

- (void) dealloc
{
	[fButtons release];
	[super dealloc];
}

#if 0
#pragma mark -
#pragma mark Geometry
#endif

// Maintaining a cache of the button boundrects simplifies the rest of the code
- (void)calcButtonRects
{
	NSRect			buttonRect		= NSMakeRect(0,0,16,16);
	unsigned int	buttonsCount	= [fButtons count];
	float			currentX		= 0.0;
	float 			currentButtonWidth;
	NSString *		downwardTriangle = [NSString stringWithFormat:@" %C", 0x25BE];

	for(unsigned int index = 0; index < buttonsCount; index += 1)
	{
		NSMutableDictionary *	buttonDefinition = [fButtons objectAtIndex:index];
//		NSImage *				icon = [buttonDefinition objectForKey:@"icon"];
		NSString *				text = [buttonDefinition objectForKey:@"title"];
		NSMenu *				menu = [buttonDefinition objectForKey:@"menu"];
		
		if( text != nil )
		{
			// Text size
			// Add popup triangle for menu buttons
			if( menu != nil && ![text hasSuffix:downwardTriangle] )
			{
				text = [text stringByAppendingString:downwardTriangle];
				[buttonDefinition setObject:text forKey:@"title"];
			}
			
			currentButtonWidth = [text sizeWithAttributes:[self titleTextAttributes]].width;
		}
		else
		{
			// Default to icon width
			currentButtonWidth = kIconButtonWidth;
			if( menu != nil )
			{
				currentButtonWidth += [downwardTriangle sizeWithAttributes:[self titleTextAttributes]].width;
			}
		}

		// Add margin to both sides
		currentButtonWidth += (kButtonInteriorVerticalEdgeMargin * 2);

		buttonRect.origin.x		= currentX;
		buttonRect.size.width 	= currentButtonWidth;

		// Cache the calculated rect
		NSValue *	rectValue = [NSValue valueWithRect:buttonRect];
		[buttonDefinition setObject:rectValue forKey:@"_cachedRect"];

		currentX += (currentButtonWidth + kHorizontalMargin);
		
	}	
	fButtonStripWidth = currentX;
}

- (NSRect)rectForButtonAtIndex:(UInt32)rectIndex inCellFrame:(NSRect)cellFrame
{	
 	NSRect buttonRect = [[[fButtons objectAtIndex:rectIndex] objectForKey:@"_cachedRect"] rectValue];
	if( !fRightToLeft )
	{
		// Left to right: need to offset the buttonRects to the right edge of the cellFrame
		buttonRect = NSOffsetRect(buttonRect, NSMaxX(cellFrame) - fButtonStripWidth, 0.0);
	}

	buttonRect.origin.y		= cellFrame.origin.y;
	buttonRect.size.height	= cellFrame.size.height;
	
	return buttonRect;
}


#if 0
#pragma mark -
#pragma mark Mouse tracking
#endif

- (UInt32) buttonIndexAtPoint:(NSPoint)point inRect:(NSRect)cellFrame ofView:(NSView *)controlView
{
	NSUInteger			buttonIndexHit	= NSNotFound;
	unsigned int	buttonsCount	= [fButtons count];
	
	for( unsigned int i = 0; i < buttonsCount; i += 1 )
	{
		NSRect buttonRect = [self rectForButtonAtIndex:i inCellFrame:cellFrame];
		
		if( [controlView mouse:point inRect:buttonRect] )
		{
			buttonIndexHit = i;
			break;
		}
	}
	
	return buttonIndexHit;
}

+ (BOOL)prefersTrackingUntilMouseUp
{
	return YES;
}

- (BOOL)trackMouse:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)controlView untilMouseUp:(BOOL)flag
{
	NSPoint origPoint;
	NSPoint	curPoint;
	BOOL	firstIteration	= YES;
	BOOL	handledMouseUp	= YES;

    origPoint	= [controlView convertPoint:[theEvent locationInWindow] fromView:nil];
	curPoint	= origPoint;

    for (;;)
	{
		NSMenu *	menu;
		NSUInteger	hitButton = [self buttonIndexAtPoint:[controlView convertPoint:[theEvent locationInWindow] fromView:nil]
							inRect:cellFrame
							ofView:controlView];
		
		// Mouse up --> invoke the appropriate invocation, if any
        if ([theEvent type] == NSLeftMouseUp)
		{
			if( hitButton != NSNotFound )
			{
				NSInvocation * invocation = [[fButtons objectAtIndex:fButtonPressedIndex] objectForKey:@"invocation"];
				
				[invocation invoke];
			}

			fButtonPressedIndex = NSNotFound;
            break;
        }
		
		
		// Exit early if the first hit wasn't a button
		if( firstIteration && hitButton == NSNotFound )
		{
			handledMouseUp = NO;
			break;
		}
		
		// Got a hit?
		if( hitButton != fButtonPressedIndex )
		{
			// Refresh old button
			if(fButtonPressedIndex != NSNotFound)
			{
				[controlView setNeedsDisplayInRect:[self rectForButtonAtIndex:fButtonPressedIndex inCellFrame:cellFrame]];
			}
			
			// Refresh current button
			if(hitButton != NSNotFound)
			{
				[controlView setNeedsDisplayInRect:[self rectForButtonAtIndex:hitButton inCellFrame:cellFrame]];
			}
			
			fButtonPressedIndex = hitButton;
		}
		
		// Pop up the menu, if we have a menu button. popUpContextMenu will track the mouse from this point forward.
		if(fButtonPressedIndex != NSNotFound)
		{
			menu = [[fButtons objectAtIndex:fButtonPressedIndex] objectForKey:@"menu"];
			if( menu != nil )
			{
				[NSMenu popUpContextMenu:menu withEvent:theEvent forView:controlView withFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
				break;
			}
		}
		
		// Next event
        theEvent = [[controlView window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
        curPoint = [controlView convertPoint:[theEvent locationInWindow] fromView:nil];

		firstIteration = NO;
    }
    
	return handledMouseUp;
}

#if 0
#pragma mark -
#pragma mark Drawing
#endif

- (BOOL)drawAsHighlighted
{
	NSView *	selfView	= [self controlView];
	NSWindow *	selfWindow	= [selfView window];
	
	return (([selfWindow firstResponder] == selfView)
				&& [selfWindow isKeyWindow]);
}

- (NSDictionary *) titleTextAttributes
{
	NSMutableDictionary *	attributes = [NSMutableDictionary dictionary];
	NSColor *				foreColor;

	if( [self isHighlighted] && [self drawAsHighlighted] )
	{
		foreColor = [NSColor alternateSelectedControlColor];
	}
	else
	{
		foreColor = [NSColor whiteColor];
	}
	
	[attributes setObject:[NSFont systemFontOfSize:9.0] forKey:NSFontAttributeName];
//	[attributes setObject:foreColor forKey:NSForegroundColorAttributeName]; TODO: should use foreColor for flat style only
	
	return attributes;
}

- (void)drawButtonContent:(id)content inRect:(NSRect)rect selected:(BOOL)selected menu:(NSMenu *)menu
{
	//
	// Draw content
	//
	if( [content isKindOfClass:[NSString class]] )
	{
		NSRect			textRect = NSInsetRect(rect, kButtonInteriorVerticalEdgeMargin, 0.5f);
		
		[content drawInRect:textRect withAttributes:[self titleTextAttributes]];
	}
	else if( [content isKindOfClass:[NSImage class]] )
	{
		NSRect			iconRect = NSInsetRect(rect, kButtonInteriorVerticalEdgeMargin, 1.5f);
		
		NSFrameRect(iconRect);
		[content compositeToPoint:iconRect.origin operation:NSCompositeSourceOver];
				
		// Add popup triangle for menu button
		if( menu != nil )
		{
			NSRect			textRect = iconRect;
			NSString *		downwardTriangle = [NSString stringWithFormat:@" %C", 0x25BE];
			
			textRect.origin.x += kIconButtonWidth;
			[downwardTriangle drawInRect:textRect withAttributes:[self titleTextAttributes]];
		}
	}
}

- (void)drawFlatButton:(id)content inRect:(NSRect)rect selected:(BOOL)selected menu:(NSMenu *)menu
{
	//
	// Draw background
	//
	NSBezierPath * 	path = [NSBezierPath bezierPathWithCapsuleRect:NSInsetRect(rect, 0.5f, 0.5f)];
	NSColor *		backgroundColor = nil;
//	NSColor *		foregroundColor = nil;
	
	// Table row is selected?
	if( [self isHighlighted] && [self drawAsHighlighted] )
	{
		if( selected )
		{
			backgroundColor = [NSColor whiteColor];
		}
		else
		{
			backgroundColor		= [NSColor colorForControlTint:[NSColor currentControlTint]];
			backgroundColor		= [[backgroundColor shadowWithLevel:0.1] blendedColorWithFraction:0.85 ofColor:[NSColor whiteColor]];
		}
	}
	else
	{
		if( selected )
		{
			backgroundColor = [NSColor colorWithDeviceWhite:0.2 alpha:1.0];
		}
		else
		{
			backgroundColor = [NSColor lightGrayColor];
		}
	}
	
	[backgroundColor set];
	[path fill];
	
	[self drawButtonContent:content inRect:rect selected:selected menu:menu];
	
}

- (void)drawClickableButton:(id)content inRect:(NSRect)rect selected:(BOOL)selected menu:(NSMenu *)menu
{
	//
	// Draw background
	//
	NSBezierPath * 	path			= [NSBezierPath bezierPathWithCapsuleRect:NSInsetRect(rect, 0.5f, 0.5f)];
	NSColor * 		borderColor		= [NSColor lightGrayColor];
	NSColor *		lightColor		= [NSColor colorWithDeviceWhite:1.0 alpha:1.0];
	NSColor *		darkColor		= [NSColor colorWithDeviceWhite:0.8 alpha:1.0];
	CXShading *		shading;

	[path setLineWidth:0.0f];
	
	if( selected )
	{
		lightColor = [NSColor colorWithDeviceWhite:0.65 alpha:1.0];
		darkColor = [NSColor colorWithDeviceWhite:0.85 alpha:1.0];
	}
	
	shading = [[CXShading alloc] initWithStartingColor:lightColor endingColor:darkColor];
	
	[shading autorelease];
	
	// Interior
	[NSGraphicsContext saveGraphicsState];

		[path addClip];
		[shading drawFromPoint:rect.origin toPoint:NSMakePoint(rect.origin.x, NSMaxY(rect))];
		
	[NSGraphicsContext restoreGraphicsState];

	// Button outline goes on top of the fill, so that we don't lose the inner antialising.
	[borderColor set];
	[path stroke];
	
	[self drawButtonContent:content inRect:rect selected:selected menu:menu];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	unsigned int	buttonsCount	= [fButtons count];
	
	for( unsigned int i = 0; i < buttonsCount; i += 1 )
	{
		NSMutableDictionary *	buttonDefinition = [fButtons objectAtIndex:i];
		NSRect					buttonRect = [self rectForButtonAtIndex:i inCellFrame:cellFrame];
		BOOL					selected = (fButtonPressedIndex == i);
		id 						content = [buttonDefinition objectForKey:@"icon"];
		NSMenu *				menu = [buttonDefinition objectForKey:@"menu"];
		
		if( content == NULL )
		{
			content = [buttonDefinition objectForKey:@"title"];
		}
		
		if( [buttonDefinition objectForKey:@"invocation"] == nil
		 	&& menu == nil)
		{
			[self drawFlatButton:content inRect:buttonRect selected:selected menu:menu];
		}
		else
		{
			[self drawClickableButton:content inRect:buttonRect selected:selected menu:menu];
		}
	}
	
	// Adjust the text bounds to avoid overlapping the buttons
	if( fRightToLeft )
	{
		cellFrame.origin.x += (fButtonStripWidth + kMarginBetweenTextAndButtons);
	}
	else
	{
		cellFrame.size.width -= (fButtonStripWidth + kMarginBetweenTextAndButtons);
	}

	[super drawWithFrame:cellFrame inView:controlView];
}

#if 0
#pragma mark -
#pragma mark Accessors
#endif

- (void)setButtonDefinitions:(NSArray *)newDefs
{
	unsigned int	buttonsCount = [newDefs count];
	NSArray *		oldButtonDefinitions = fButtons;
	
	// Get mutable copies of the button definitions; we want to store additional data in them
	fButtons = [[NSMutableArray alloc] init];

	for(unsigned int index = 0; index < buttonsCount; index += 1)
	{
		NSDictionary *	button = [newDefs objectAtIndex:index];
		
		[fButtons addObject:[button mutableCopy]];
	}
	
	[oldButtonDefinitions release];
	
	[self calcButtonRects];
	
	// Reset pressed index
	fButtonPressedIndex = NSNotFound;
}

- (NSArray *)buttonDefinitions
{
	return fButtons;
}

@end
