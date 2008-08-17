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
    self=[super initWithFrame:frameRect pullsDown:YES];
    if (self) {
        [self setBezelStyle:NSRegularSquareBezelStyle];
        [self setBordered:NO];
        [self setTitle:@""];
        [self setPreferredEdge:NSMaxXEdge];
        _PSMTabBarOverflowPopUpImage = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"overflowImage"]];
    }
    return self;
}

- (void)dealloc
{
    [_PSMTabBarOverflowPopUpImage release];
    [super dealloc];
}

- (void)drawRect:(NSRect)rect
{
    if(_PSMTabBarOverflowPopUpImage == nil){
        [super drawRect:rect];
        return;
    }
    NSSize imageSize = [_PSMTabBarOverflowPopUpImage size];
    rect.origin.x = NSMidX(rect) - (imageSize.width * 0.5);
    rect.origin.y = NSMidY(rect) - (imageSize.height * 0.5);
    if([self isFlipped]) {
        rect.origin.y += imageSize.height;
    }
    [_PSMTabBarOverflowPopUpImage compositeToPoint:rect.origin operation:NSCompositeSourceOver];
}

#pragma mark -
#pragma mark Archiving

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [super encodeWithCoder:aCoder];
    if ([aCoder allowsKeyedCoding]) {
        [aCoder encodeObject:_PSMTabBarOverflowPopUpImage forKey:@"PSMTabBarOverflowPopUpImage"];
    }
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        if ([aDecoder allowsKeyedCoding]) {
            _PSMTabBarOverflowPopUpImage = [[aDecoder decodeObjectForKey:@"PSMTabBarOverflowPopUpImage"] retain];
        }
    }
    return self;
}

@end
