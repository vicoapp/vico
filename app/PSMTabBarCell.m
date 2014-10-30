//
//  PSMTabBarCell.m
//  PSMTabBarControl
//
//  Created by John Pannell on 10/13/05.
//  Copyright 2005 Positive Spin Media. All rights reserved.
//

#import "PSMTabBarCell.h"
#import "PSMTabBarControl.h"
#import "PSMTabStyle.h"
#import "PSMProgressIndicator.h"
#import "PSMTabDragAssistant.h"
#include "logging.h"


@implementation PSMTabBarCell

@synthesize modified = _modified;

#pragma mark -
#pragma mark Creation/Destruction

- (id)initWithControlView:(PSMTabBarControl *)controlView
{
    self = [super init];
    if(self){
        _myControlView = controlView;
        _closeButtonTrackingTag = 0;
        _cellTrackingTag = 0;
        _closeButtonOver = NO;
        _closeButtonPressed = NO;
        _indicator = [[PSMProgressIndicator alloc] initWithFrame:NSMakeRect(0.0,0.0,kPSMTabBarIndicatorWidth,kPSMTabBarIndicatorWidth)];
        [_indicator setStyle:NSProgressIndicatorSpinningStyle];
        [_indicator setAutoresizingMask:NSViewMinYMargin];
	[_indicator setControlSize:NSSmallControlSize];
        _hasCloseButton = YES;
        _isCloseButtonSuppressed = NO;
        _count = 0;
        _isPlaceholder = NO;
    }
    DEBUG_INIT();
    return self;
}

- (id)initPlaceholderWithFrame:(NSRect)frame expanded:(BOOL)value inControlView:(PSMTabBarControl *)controlView
{
    self = [super init];
    if(self){
        _myControlView = controlView;
        _isPlaceholder = YES;
        if(!value)
            frame.size.width = 0.0;
        [self setFrame:frame];
        _closeButtonTrackingTag = 0;
        _cellTrackingTag = 0;
        _closeButtonOver = NO;
        _closeButtonPressed = NO;
        _indicator = nil;
        _hasCloseButton = YES;
        _isCloseButtonSuppressed = NO;
        _count = 0;

        if(value){
            [self setCurrentStep:(kPSMTabDragAnimationSteps - 1)];
        } else {
            [self setCurrentStep:0];
        }

    }

    DEBUG_INIT();
    return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	[_indicator removeFromSuperviewWithoutNeedingDisplay];
}

#pragma mark -
#pragma mark Accessors

- (id)controlView
{
    return _myControlView;
}

- (void)setControlView:(id)view
{
    // no retain release pattern, as this simply switches a tab to another view.
    _myControlView = view;
}

- (NSTrackingRectTag)closeButtonTrackingTag
{
    return _closeButtonTrackingTag;
}

- (void)setCloseButtonTrackingTag:(NSTrackingRectTag)tag
{
    _closeButtonTrackingTag = tag;
}

- (NSTrackingRectTag)cellTrackingTag
{
    return _cellTrackingTag;
}

- (void)setCellTrackingTag:(NSTrackingRectTag)tag
{
    _cellTrackingTag = tag;
}

- (float)width
{
    return _frame.size.width;
}

- (NSRect)frame
{
    return _frame;
}

- (void)setFrame:(NSRect)rect
{
    _frame = rect;
}

- (void)setStringValue:(NSString *)aString
{
    [super setStringValue:aString];
    _stringSize = [[self attributedStringValue] size];
    // need to redisplay now - binding observation was too quick.
    [_myControlView update];
}

- (NSSize)stringSize
{
    return _stringSize;
}

- (NSAttributedString *)attributedStringValue
{
    return [(id <PSMTabStyle>)[_myControlView style] attributedStringValueForTabCell:self];
}

- (int)tabState
{
    return _tabState;
}

- (void)setTabState:(int)state
{
    _tabState = state;
}

- (NSProgressIndicator *)indicator
{
    return _indicator;
}

- (BOOL)isInOverflowMenu
{
    return _isInOverflowMenu;
}

- (void)setIsInOverflowMenu:(BOOL)value
{
    _isInOverflowMenu = value;
}

- (BOOL)closeButtonPressed
{
    return _closeButtonPressed;
}

- (void)setCloseButtonPressed:(BOOL)value
{
    _closeButtonPressed = value;
}

- (BOOL)closeButtonOver
{
    return _closeButtonOver;
}

- (void)setCloseButtonOver:(BOOL)value
{
    _closeButtonOver = value;
}

- (BOOL)hasCloseButton
{
    return _hasCloseButton;
}

- (void)setHasCloseButton:(BOOL)set;
{
    _hasCloseButton = set;
}

- (void)setCloseButtonSuppressed:(BOOL)suppress;
{
    _isCloseButtonSuppressed = suppress;
}

- (BOOL)isCloseButtonSuppressed;
{
    return _isCloseButtonSuppressed;
}

- (BOOL)hasIcon
{
    return _hasIcon;
}

- (void)setHasIcon:(BOOL)value
{
    _hasIcon = value;
    [_myControlView update]; // binding notice is too fast
}

- (int)count
{
    return _count;
}

- (void)setCount:(int)value
{
    _count = value;
    [_myControlView update]; // binding notice is too fast
}

- (BOOL)isPlaceholder
{
    return _isPlaceholder;
}

- (void)setIsPlaceholder:(BOOL)value;
{
    _isPlaceholder = value;
}

- (int)currentStep
{
    return _currentStep;
}

- (void)setCurrentStep:(int)value
{
    if(value < 0)
        value = 0;

    if(value > (kPSMTabDragAnimationSteps - 1))
        value = (kPSMTabDragAnimationSteps - 1);

    _currentStep = value;
}

#pragma mark -
#pragma mark Component Attributes

- (NSRect)indicatorRectForFrame:(NSRect)cellFrame
{
    return [(id <PSMTabStyle>)[_myControlView style] indicatorRectForTabCell:self];
}

- (NSRect)closeButtonRectForFrame:(NSRect)cellFrame
{
    return [(id <PSMTabStyle>)[_myControlView style] closeButtonRectForTabCell:self];
}

- (float)minimumWidthOfCell
{
    return [(id <PSMTabStyle>)[_myControlView style] minimumWidthOfTabCell:self];
}

- (float)desiredWidthOfCell
{
    return [(id <PSMTabStyle>)[_myControlView style] desiredWidthOfTabCell:self];
}

#pragma mark -
#pragma mark Drawing

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    if(_isPlaceholder){
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.2] set];
        NSRectFillUsingOperation(cellFrame, NSCompositeSourceAtop);
        return;
    }

    [(id <PSMTabStyle>)[_myControlView style] drawTabCell:self];
}

#pragma mark -
#pragma mark Tracking

- (void)mouseEntered:(NSEvent *)theEvent
{
    // check for which tag
    if([theEvent trackingNumber] == _closeButtonTrackingTag){
        _closeButtonOver = YES;
    }
    if([theEvent trackingNumber] == _cellTrackingTag){
        [self setHighlighted:YES];
    }
    [_myControlView setNeedsDisplay];
}

- (void)mouseExited:(NSEvent *)theEvent
{
    // check for which tag
    if([theEvent trackingNumber] == _closeButtonTrackingTag){
        _closeButtonOver = NO;
    }
    if([theEvent trackingNumber] == _cellTrackingTag){
        [self setHighlighted:NO];
    }
    [_myControlView setNeedsDisplay];
}

#pragma mark -
#pragma mark Drag Support

- (NSImage*)dragImageForRect:(NSRect)cellFrame
{
    if(([self state] == NSOnState) && ([[_myControlView styleName] isEqualToString:@"Metal"]))
        cellFrame.size.width += 1.0;
    [_myControlView lockFocus];
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:cellFrame];
    [_myControlView unlockFocus];
    NSImage *image = [[NSImage alloc] initWithSize:[rep size]];
    [image addRepresentation:rep];
    NSImage *returnImage = [[NSImage alloc] initWithSize:[rep size]];
    [returnImage lockFocus];
	[image drawAtPoint:NSMakePoint(0.0, 0.0) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:0.7];
    [returnImage unlockFocus];
    if(![[self indicator] isHidden]){
        NSImage *indicatorImage = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"pi"]];
        [returnImage lockFocus];
        NSPoint indicatorPoint = NSMakePoint([self frame].size.width - MARGIN_X - kPSMTabBarIndicatorWidth, MARGIN_Y);
        if(([self state] == NSOnState) && ([[_myControlView styleName] isEqualToString:@"Metal"]))
            indicatorPoint.y += 1.0;
        [indicatorImage drawAtPoint:indicatorPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:0.7];
        [returnImage unlockFocus];
    }
    return returnImage;
}

@end
