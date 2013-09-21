//
//  PSMOverflowPopUpButton.m
//  PSMTabBarControl
//
//  Created by John Pannell on 11/4/05.
//  Copyright 2005 Positive Spin Media. All rights reserved.
//

#import "PSMOverflowPopUpButton.h"
#import "PSMTabBarControl.h"

@implementation PSMOverflowPopUpButton

- (id)initWithFrame:(NSRect)frameRect pullsDown:(BOOL)flag
{
	if ((self = [super initWithFrame:frameRect pullsDown:YES]) != nil) {
		[self setBezelStyle:NSRegularSquareBezelStyle];
		[self setBordered:NO];
		[self setTitle:@""];
		[self setPreferredEdge:NSMaxXEdge];
		_PSMTabBarOverflowPopUpImage = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"overflowImage"]];
		_PSMTabBarOverflowDownPopUpImage = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"overflowImagePressed"]];
	}
	return self;
}


- (void)drawRect:(NSRect)rect
{
    if(_PSMTabBarOverflowPopUpImage == nil){
        [super drawRect:rect];
        return;
    }

    NSImage *image = (_down) ? _PSMTabBarOverflowDownPopUpImage : _PSMTabBarOverflowPopUpImage;
	NSSize imageSize = [image size];
    rect.origin.x = NSMidX(rect) - (imageSize.width * 0.5);
    rect.origin.y = NSMidY(rect) - (imageSize.height * 0.5);
    if([self isFlipped]) {
        rect.origin.y += imageSize.height;
    }
    [image compositeToPoint:rect.origin operation:NSCompositeSourceOver];
}

- (void)mouseDown:(NSEvent *)event
{
	_down = YES;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationReceived:) name:NSMenuDidEndTrackingNotification object:[self menu]];
	[self setNeedsDisplay:YES];
	[super mouseDown:event];
}

- (void)notificationReceived:(NSNotification *)notification
{
	_down = NO;
	[self setNeedsDisplay:YES];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
