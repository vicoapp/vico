//
//  PSMOverflowPopUpButton.h
//  NetScrape
//
//  Created by John Pannell on 8/4/04.
//  Copyright 2004 Positive Spin Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PSMRolloverButton : NSButton
{
    NSImage             *_rolloverImage;
    NSImage             *_usualImage;
    NSTrackingRectTag   _myTrackingRectTag;
}

@property (nonatomic,readwrite,strong) NSImage *rolloverImage;
@property (nonatomic,readwrite,strong) NSImage *usualImage;

// tracking rect for mouse events
- (void)addTrackingRect;
- (void)removeTrackingRect;
@end
