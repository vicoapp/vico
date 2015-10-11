//
//  PSMMetalTabStyle.m
//  PSMTabBarControl
//
//  Created by John Pannell on 2/17/06.
//  Copyright 2006 Positive Spin Media. All rights reserved.
//

#import "PSMMetalTabStyle.h"
#import "PSMTabBarCell.h"
#import "PSMTabBarControl.h"
#include "logging.h"

#define kPSMMetalObjectCounterRadius 7.0
#define kPSMMetalCounterMinWidth 20

@implementation PSMMetalTabStyle

- (NSString *)name
{
    return @"Metal";
}

#pragma mark -
#pragma mark Creation/Destruction

- (id) init
{
	if ((self = [super init])) {
		_metalCloseButton = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"TabClose_Front"]];
		_metalCloseButtonDown = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"TabClose_Front_Pressed"]];
		_metalCloseButtonOver = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"TabClose_Front_Rollover"]];

		_metalCloseModifiedButton = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"TabCloseModified_Front"]];
		_metalCloseModifiedButtonDown = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"TabCloseModified_Front_Pressed"]];
		_metalCloseModifiedButtonOver = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"TabCloseModified_Front_Rollover"]];

		_addTabButtonImage = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"TabNewMetal"]];
		_addTabButtonPressedImage = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"TabNewMetalPressed"]];
		_addTabButtonRolloverImage = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"TabNewMetalRollover"]];
	}
	DEBUG_INIT();
	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
}

#pragma mark -
#pragma mark Control Specific

- (float)leftMarginForTabBarControl
{
    return 10.0f;
}

- (float)rightMarginForTabBarControl
{
    return 24.0f;
}

#pragma mark -
#pragma mark Add Tab Button

- (NSImage *)addTabButtonImage
{
    return _addTabButtonImage;
}

- (NSImage *)addTabButtonPressedImage
{
    return _addTabButtonPressedImage;
}

- (NSImage *)addTabButtonRolloverImage
{
    return _addTabButtonRolloverImage;
}

#pragma mark -
#pragma mark Cell Specific

- (NSRect) closeButtonRectForTabCell:(PSMTabBarCell *)cell
{
    NSRect cellFrame = [cell frame];

    if ([cell hasCloseButton] == NO) {
        return NSZeroRect;
    }

    NSRect result;
    result.size = [_metalCloseButton size];
    result.origin.x = cellFrame.origin.x + MARGIN_X;
    result.origin.y = cellFrame.origin.y + MARGIN_Y + 2.0;

    if([cell state] == NSOnState){
        result.origin.y -= 1;
    }

    return result;
}

- (NSRect)iconRectForTabCell:(PSMTabBarCell *)cell
{
    NSRect cellFrame = [cell frame];

    if ([cell hasIcon] == NO) {
        return NSZeroRect;
    }

    NSRect result;
    result.size = NSMakeSize(kPSMTabBarIconWidth, kPSMTabBarIconWidth);
    result.origin.x = cellFrame.origin.x + MARGIN_X;
    result.origin.y = cellFrame.origin.y + MARGIN_Y;

    if([cell hasCloseButton] && ![cell isCloseButtonSuppressed])
        result.origin.x += [_metalCloseButton size].width + kPSMTabBarCellPadding;

    if([cell state] == NSOnState){
        result.origin.y += 1;
    }

    return result;
}

- (NSRect)indicatorRectForTabCell:(PSMTabBarCell *)cell
{
    NSRect cellFrame = [cell frame];

    if ([[cell indicator] isHidden]) {
        return NSZeroRect;
    }

    NSRect result;
    result.size = NSMakeSize(kPSMTabBarIndicatorWidth, kPSMTabBarIndicatorWidth);
    result.origin.x = cellFrame.origin.x + cellFrame.size.width - MARGIN_X - kPSMTabBarIndicatorWidth;
    result.origin.y = cellFrame.origin.y + MARGIN_Y;

    if([cell state] == NSOnState){
        result.origin.y -= 1;
    }

    return result;
}

- (NSRect)objectCounterRectForTabCell:(PSMTabBarCell *)cell
{
    NSRect cellFrame = [cell frame];

    if ([cell count] == 0) {
        return NSZeroRect;
    }

    float countWidth = [[self attributedObjectCountValueForTabCell:cell] size].width;
    countWidth += (2 * kPSMMetalObjectCounterRadius - 6.0);
    if(countWidth < kPSMMetalCounterMinWidth)
        countWidth = kPSMMetalCounterMinWidth;

    NSRect result;
    result.size = NSMakeSize(countWidth, 2 * kPSMMetalObjectCounterRadius); // temp
    result.origin.x = cellFrame.origin.x + cellFrame.size.width - MARGIN_X - result.size.width;
    result.origin.y = cellFrame.origin.y + MARGIN_Y + 1.0;

    if(![[cell indicator] isHidden])
        result.origin.x -= kPSMTabBarIndicatorWidth + kPSMTabBarCellPadding;

    return result;
}


- (float)minimumWidthOfTabCell:(PSMTabBarCell *)cell
{
    float resultWidth = 0.0;

    // left margin
    resultWidth = MARGIN_X;

    // close button?
    if([cell hasCloseButton] && ![cell isCloseButtonSuppressed])
        resultWidth += [_metalCloseButton size].width + kPSMTabBarCellPadding;

    // icon?
    if([cell hasIcon])
        resultWidth += kPSMTabBarIconWidth + kPSMTabBarCellPadding;

    // the label
    resultWidth += kPSMMinimumTitleWidth;

    // object counter?
    if([cell count] > 0)
        resultWidth += [self objectCounterRectForTabCell:cell].size.width + kPSMTabBarCellPadding;

    // indicator?
    if ([[cell indicator] isHidden] == NO)
        resultWidth += kPSMTabBarCellPadding + kPSMTabBarIndicatorWidth;

    // right margin
    resultWidth += MARGIN_X;

    return ceil(resultWidth);
}

- (float)desiredWidthOfTabCell:(PSMTabBarCell *)cell
{
    float resultWidth = 0.0;

    // left margin
    resultWidth = MARGIN_X;

    // close button?
    if ([cell hasCloseButton] && ![cell isCloseButtonSuppressed])
        resultWidth += [_metalCloseButton size].width + kPSMTabBarCellPadding;

    // icon?
    if([cell hasIcon])
        resultWidth += kPSMTabBarIconWidth + kPSMTabBarCellPadding;

    // the label
    resultWidth += [[cell attributedStringValue] size].width;

    // object counter?
    if([cell count] > 0)
        resultWidth += [self objectCounterRectForTabCell:cell].size.width + kPSMTabBarCellPadding;

    // indicator?
    if ([[cell indicator] isHidden] == NO)
        resultWidth += kPSMTabBarCellPadding + kPSMTabBarIndicatorWidth;

    // right margin
    resultWidth += MARGIN_X;

    return ceil(resultWidth);
}

#pragma mark -
#pragma mark Cell Values

- (NSAttributedString *)attributedObjectCountValueForTabCell:(PSMTabBarCell *)cell
{
    NSMutableAttributedString *attrStr;
    NSFontManager *fm = [NSFontManager sharedFontManager];
    NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
    [nf setLocalizesFormat:YES];
    [nf setFormat:@"0"];
    [nf setHasThousandSeparators:YES];
    NSString *contents = [nf stringFromNumber:[NSNumber numberWithInt:[cell count]]];
    attrStr = [[NSMutableAttributedString alloc] initWithString:contents];
    NSRange range = NSMakeRange(0, [contents length]);

    // Add font attribute
    [attrStr addAttribute:NSFontAttributeName value:[fm convertFont:[NSFont fontWithName:@"Helvetica" size:11.0] toHaveTrait:NSBoldFontMask] range:range];
    [attrStr addAttribute:NSForegroundColorAttributeName value:[[NSColor whiteColor] colorWithAlphaComponent:0.85] range:range];

    return attrStr;
}

- (NSAttributedString *)attributedStringValueForTabCell:(PSMTabBarCell *)cell
{
    NSMutableAttributedString *attrStr;
    NSString *contents = [cell stringValue];
    attrStr = [[NSMutableAttributedString alloc] initWithString:contents];
    NSRange range = NSMakeRange(0, [contents length]);

    // Add font attribute
    [attrStr addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:11.0] range:range];
    //[attrStr addAttribute:NSForegroundColorAttributeName value:[[NSColor textColor] colorWithAlphaComponent:0.75] range:range];
    [attrStr addAttribute:NSForegroundColorAttributeName value:[NSColor textColor] range:range];

#if 0
    // Add shadow attribute
    NSShadow* shadow;
    shadow = [[[NSShadow alloc] init] autorelease];
    float shadowAlpha;
    if(([cell state] == NSOnState) || [cell isHighlighted]){
        shadowAlpha = 0.8;
    } else {
        shadowAlpha = 0.5;
    }
    [shadow setShadowColor:[NSColor colorWithCalibratedWhite:1.0 alpha:shadowAlpha]];
    [shadow setShadowOffset:NSMakeSize(0, -1)];
    [shadow setShadowBlurRadius:1.0];
    [attrStr addAttribute:NSShadowAttributeName value:shadow range:range];
#endif

    // Paragraph Style for Truncating Long Text
    static NSMutableParagraphStyle *TruncatingTailParagraphStyle = nil;
    if (!TruncatingTailParagraphStyle) {
        TruncatingTailParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [TruncatingTailParagraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
        [TruncatingTailParagraphStyle setAlignment:NSCenterTextAlignment];
    }
    [attrStr addAttribute:NSParagraphStyleAttributeName value:TruncatingTailParagraphStyle range:range];

    return attrStr;
}

#pragma mark -
#pragma mark Drawing

- (void)drawTabCell:(PSMTabBarCell *)cell
{
    NSRect cellFrame = [cell frame];
    NSColor * lineColor = nil;
    NSBezierPath* bezier = [NSBezierPath bezierPath];
    lineColor = [NSColor darkGrayColor];

    if ([cell state] == NSOnState) {
        // selected tab
        NSRect aRect = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y, cellFrame.size.width, cellFrame.size.height-2.5);
        aRect.size.height -= 0.5;

        // background
        NSDrawWindowBackground(aRect);

        aRect.size.height+=0.5;

        // frame
        aRect.origin.x += 0.5;
        [lineColor set];
        [bezier moveToPoint:NSMakePoint(aRect.origin.x, aRect.origin.y)];
        [bezier lineToPoint:NSMakePoint(aRect.origin.x, aRect.origin.y+aRect.size.height-1.5)];
        [bezier lineToPoint:NSMakePoint(aRect.origin.x+1.5, aRect.origin.y+aRect.size.height)];
        [bezier lineToPoint:NSMakePoint(aRect.origin.x+aRect.size.width-1.5, aRect.origin.y+aRect.size.height)];
        [bezier lineToPoint:NSMakePoint(aRect.origin.x+aRect.size.width, aRect.origin.y+aRect.size.height-1.5)];
        [bezier lineToPoint:NSMakePoint(aRect.origin.x+aRect.size.width, aRect.origin.y)];
        if([[cell controlView] frame].size.height < 2){
            // special case of hidden control; need line across top of cell
            [bezier moveToPoint:NSMakePoint(aRect.origin.x, aRect.origin.y+0.5)];
            [bezier lineToPoint:NSMakePoint(aRect.origin.x+aRect.size.width, aRect.origin.y+0.5)];
        }
        [bezier stroke];
    } else {

        // unselected tab
        NSRect aRect = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y, cellFrame.size.width, cellFrame.size.height);
        aRect.origin.y += 0.5;
        aRect.origin.x += 1.5;
        aRect.size.width -= 1;

        // rollover
        if ([cell isHighlighted]) {
            [[NSColor colorWithCalibratedWhite:0.0 alpha:0.1] set];
            NSRectFillUsingOperation(aRect, NSCompositeSourceAtop);
        }

        aRect.origin.x -= 1;
        aRect.size.width += 1;

        // frame
        [lineColor set];
        [bezier moveToPoint:NSMakePoint(aRect.origin.x, aRect.origin.y)];
        [bezier lineToPoint:NSMakePoint(aRect.origin.x + aRect.size.width, aRect.origin.y)];
        if(!([cell tabState] & PSMTab_RightIsSelectedMask)){
            [bezier lineToPoint:NSMakePoint(aRect.origin.x + aRect.size.width, aRect.origin.y + aRect.size.height)];
        }
        [bezier stroke];
    }

    [self drawInteriorWithTabCell:cell inView:[cell controlView]];
}



- (void)drawInteriorWithTabCell:(PSMTabBarCell *)cell inView:(NSView*)controlView
{
	NSRect cellFrame = [cell frame];
	float labelPosition = cellFrame.origin.x + MARGIN_X;

	// close button
	if ([cell hasCloseButton] && ![cell isCloseButtonSuppressed]) {
		NSSize closeButtonSize = NSZeroSize;
		NSRect closeButtonRect = [cell closeButtonRectForFrame:cellFrame];
		NSImage* baseCloseButton = nil, *closeButton = nil;

		if (cell.isModified) {
			baseCloseButton = _metalCloseModifiedButton;
			if ([cell closeButtonOver]) baseCloseButton = _metalCloseModifiedButtonOver;
			if ([cell closeButtonPressed]) baseCloseButton = _metalCloseModifiedButtonDown;
		} else {
			baseCloseButton = _metalCloseButton;
			if ([cell closeButtonOver]) baseCloseButton = _metalCloseButtonOver;
			if ([cell closeButtonPressed]) baseCloseButton = _metalCloseButtonDown;
		}

		closeButtonSize = [baseCloseButton size];
        
		if ([controlView isFlipped]) {
            closeButton = [[NSImage alloc] initWithSize:[baseCloseButton size]];
            
            [closeButton lockFocusFlipped:YES];
            [baseCloseButton drawAtPoint:NSZeroPoint fromRect:NSMakeRect(0, 0, closeButtonSize.width, closeButtonSize.height) operation:NSCompositeSourceOver fraction:1.0];
            [closeButton unlockFocus];
        } else {
            closeButton = baseCloseButton;
        }

		[closeButton drawAtPoint:closeButtonRect.origin fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];

		// scoot label over
		labelPosition += closeButtonSize.width + kPSMTabBarCellPadding;
	}

	// icon
	if([cell hasIcon]){
		NSRect iconRect = [self iconRectForTabCell:cell];
		NSImage *baseIcon = [[[(NSTabViewItem *)[cell representedObject] identifier] content] icon], *icon = nil;
        
		if ([controlView isFlipped]) {
            icon = [[NSImage alloc] initWithSize:[baseIcon size]];
            
            [icon lockFocusFlipped:YES];
            [baseIcon drawAtPoint:NSZeroPoint fromRect:NSMakeRect(0, 0, baseIcon.size.width, baseIcon.size.height) operation:NSCompositeSourceOver fraction:1.0];
            [icon unlockFocus];
        } else {
            baseIcon = icon;
        }
        
		[icon drawAtPoint:iconRect.origin fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];

		// scoot label over
		labelPosition += iconRect.size.width + kPSMTabBarCellPadding;
	}

	// object counter
	if([cell count] > 0){
		[[NSColor colorWithCalibratedWhite:0.3 alpha:0.6] set];
		NSBezierPath *path = [NSBezierPath bezierPath];
		NSRect myRect = [self objectCounterRectForTabCell:cell];
		if([cell state] == NSOnState)
			myRect.origin.y -= 1.0;
		[path moveToPoint:NSMakePoint(myRect.origin.x + kPSMMetalObjectCounterRadius, myRect.origin.y)];
		[path lineToPoint:NSMakePoint(myRect.origin.x + myRect.size.width - kPSMMetalObjectCounterRadius, myRect.origin.y)];
		[path appendBezierPathWithArcWithCenter:NSMakePoint(myRect.origin.x + myRect.size.width - kPSMMetalObjectCounterRadius, myRect.origin.y + kPSMMetalObjectCounterRadius) radius:kPSMMetalObjectCounterRadius startAngle:270.0 endAngle:90.0];
		[path lineToPoint:NSMakePoint(myRect.origin.x + kPSMMetalObjectCounterRadius, myRect.origin.y + myRect.size.height)];
		[path appendBezierPathWithArcWithCenter:NSMakePoint(myRect.origin.x + kPSMMetalObjectCounterRadius, myRect.origin.y + kPSMMetalObjectCounterRadius) radius:kPSMMetalObjectCounterRadius startAngle:90.0 endAngle:270.0];
		[path fill];

		// draw attributed string centered in area
		NSRect counterStringRect;
		NSAttributedString *counterString = [self attributedObjectCountValueForTabCell:cell];
		counterStringRect.size = [counterString size];
		counterStringRect.origin.x = myRect.origin.x + ((myRect.size.width - counterStringRect.size.width) / 2.0) + 0.25;
		counterStringRect.origin.y = myRect.origin.y + ((myRect.size.height - counterStringRect.size.height) / 2.0) + 0.5;
		[counterString drawInRect:counterStringRect];
	}

	// label rect
	NSRect labelRect;
	labelRect.origin.x = labelPosition;
	labelRect.size.width = cellFrame.size.width - (labelRect.origin.x - cellFrame.origin.x) - kPSMTabBarCellPadding;
	labelRect.size.height = cellFrame.size.height;
	labelRect.origin.y = cellFrame.origin.y + MARGIN_Y;

	if(![[cell indicator] isHidden])
		labelRect.size.width -= (kPSMTabBarIndicatorWidth + kPSMTabBarCellPadding);

	if([cell count] > 0)
		labelRect.size.width -= ([self objectCounterRectForTabCell:cell].size.width + kPSMTabBarCellPadding);

	// label
	[[cell attributedStringValue] drawInRect:labelRect];
}

- (void)drawTabBar:(PSMTabBarControl *)bar inRect:(NSRect)rect
{
    NSDrawWindowBackground(rect);
    [[NSColor colorWithCalibratedWhite:0.3 alpha:0.2] set];
    NSRectFillUsingOperation(rect, NSCompositeSourceAtop);
    [[NSColor darkGrayColor] set];
    [NSBezierPath strokeLineFromPoint:NSMakePoint(rect.origin.x,rect.origin.y+0.5) toPoint:NSMakePoint(rect.origin.x+rect.size.width,rect.origin.y+0.5)];
    [NSBezierPath strokeLineFromPoint:NSMakePoint(rect.origin.x,rect.origin.y+rect.size.height-0.5) toPoint:NSMakePoint(rect.origin.x+rect.size.width,rect.origin.y+rect.size.height-0.5)];

    // no tab view == not connected
    if(![bar delegate]){
        NSRect labelRect = rect;
        labelRect.size.height -= 4.0;
        labelRect.origin.y += 4.0;
        NSMutableAttributedString *attrStr;
        NSString *contents = @"PSMTabBarControl";
        attrStr = [[NSMutableAttributedString alloc] initWithString:contents];
        NSRange range = NSMakeRange(0, [contents length]);
        [attrStr addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:11.0] range:range];

	NSMutableParagraphStyle *centeredParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[centeredParagraphStyle setAlignment:NSCenterTextAlignment];
        [attrStr addAttribute:NSParagraphStyleAttributeName value:centeredParagraphStyle range:range];
        [attrStr drawInRect:labelRect];

	return;
    }

    // draw cells
    for (PSMTabBarCell *cell in [bar cells])
        if (![cell isInOverflowMenu])
            [cell drawWithFrame:[cell frame] inView:bar];
}

@end
