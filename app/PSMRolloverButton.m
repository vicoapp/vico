//
//  PSMOverflowPopUpButton.m
//  NetScrape
//
//  Created by John Pannell on 8/4/04.
//  Copyright 2004 Positive Spin Media. All rights reserved.
//

#import "PSMRolloverButton.h"

@implementation PSMRolloverButton

@synthesize rolloverImage = _rolloverImage;
@synthesize usualImage = _usualImage;


- (void)addTrackingRect
{
    // assign a tracking rect to watch for mouse enter/exit
    _myTrackingRectTag = [self addTrackingRect:[self bounds] owner:self userData:nil assumeInside:NO];
}

- (void)removeTrackingRect
{
    [self removeTrackingRect:_myTrackingRectTag];
}

// override for rollover effect
- (void)mouseEntered:(NSEvent *)theEvent;
{
    // set rollover image
    [self setImage:_rolloverImage];
    [self setNeedsDisplay];
    [[self superview] setNeedsDisplay:YES]; // eliminates a drawing artifact
}

- (void)mouseExited:(NSEvent *)theEvent;
{
    // restore usual image
    [self setImage:_usualImage];
    [self setNeedsDisplay];
    [[self superview] setNeedsDisplay:YES]; // eliminates a drawing artifact
}

- (void)mouseDown:(NSEvent *)theEvent
{
    // eliminates drawing artifact
    [[NSRunLoop currentRunLoop] performSelector:@selector(display) target:[self superview] argument:nil order:1 modes:[NSArray arrayWithObjects:@"NSEventTrackingRunLoopMode", @"NSDefaultRunLoopMode", nil]];
    [super mouseDown:theEvent];
}

- (void)resetCursorRects
{
    // called when the button rect has been changed
    [self removeTrackingRect];
    [self addTrackingRect];
    [[self superview] setNeedsDisplay:YES]; // eliminates a drawing artifact
}

@end
