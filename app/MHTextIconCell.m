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

#import "MHTextIconCell.h"
#include "logging.h"

/*
 * http://developer.apple.com/library/mac/#samplecode/ImageBackground/Introduction/Intro.html
 */

@implementation MHTextIconCell

@synthesize modified = _modified;
@synthesize statusImage = _statusImage;
@synthesize modImage = _modImage;

- (void)dealloc
{
	DEBUG_DEALLOC();
}

- (id)copyWithZone:(NSZone *)zone
{
	// NSCopyObject() horror story!?
	// http://robnapier.net/blog/implementing-nscopying-439
	MHTextIconCell *copy = (MHTextIconCell *)[super copyWithZone:zone];
	copy->_modified = _modified;
	copy->_statusImage = _statusImage;
	copy->_modImage = _modImage;
	return copy;
}

- (void)editWithFrame:(NSRect)aRect
               inView:(NSView *)controlView
               editor:(NSText *)textObj
             delegate:(id)anObject
                event:(NSEvent *)theEvent
{
	NSRect textFrame, imageFrame;
	NSDivideRect(aRect, &imageFrame, &textFrame, 4 + [self.image size].width, NSMinXEdge);
	NSSize sz = [[self attributedStringValue] size];
	CGFloat d = (textFrame.size.height - sz.height) / 2.0;
	if (d > 0) {
		textFrame.origin.y += d;
		textFrame.size.height -= 2*d;
	}
	[super editWithFrame:textFrame
                      inView:controlView
                      editor:textObj
                    delegate:anObject
                       event:theEvent];
}

- (void)selectWithFrame:(NSRect)aRect
                 inView:(NSView *)controlView
                 editor:(NSText *)textObj
               delegate:(id)anObject
                  start:(NSInteger)selStart
                 length:(NSInteger)selLength
{
	NSRect textFrame, imageFrame;
	NSDivideRect(aRect, &imageFrame, &textFrame, 4 + [self.image size].width, NSMinXEdge);
	NSSize sz = [[self attributedStringValue] size];
	CGFloat d = (textFrame.size.height - sz.height) / 2.0;
	if (d > 0) {
		textFrame.origin.y += d;
		textFrame.size.height -= 2*d;
	}
	[super selectWithFrame:textFrame
                        inView:controlView
                        editor:textObj
                      delegate:anObject
                         start:selStart
                        length:selLength];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSSize imageSize;
	NSRect imageFrame = NSZeroRect;

	if (self.image != nil) {
		imageSize = [self.image size];
		NSDivideRect(cellFrame, &imageFrame, &cellFrame, 4 + imageSize.width, NSMinXEdge);
		if ([self drawsBackground]) {
			[[self backgroundColor] set];
			NSRectFill(imageFrame);
		}
		imageFrame.origin.x += 3;
		imageFrame.size = imageSize;

        imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);

        [self.image drawInRect:imageFrame];
	}

	if (_statusImage != nil) {
		imageSize = [_statusImage size];
		NSPoint p = NSMakePoint(NSMaxX(cellFrame) - imageSize.width, cellFrame.origin.y);
		p.y += ceil((cellFrame.size.height - imageSize.height) / 2);
        
        [_statusImage drawInRect:NSMakeRect(p.x, p.y, imageSize.width, imageSize.height)];
	}

	if (_modified) {
		if (_modImage == nil)
			_modImage = [NSImage imageNamed:NSImageNameStatusPartiallyAvailable];
		NSPoint modPoint = cellFrame.origin;
		NSSize modImageSize = [_modImage size];
        modPoint.y += ceil((cellFrame.size.height - modImageSize.height) / 2);
		modPoint.x = imageFrame.origin.x - modImageSize.width;
        
        [_modImage drawInRect:NSMakeRect(modPoint.x, modPoint.y, modImageSize.width, modImageSize.height)];
	}

	NSSize sz = [[self attributedStringValue] size];
	CGFloat d = (cellFrame.size.height - sz.height) / 2.0;
	if (d > 0) {
		cellFrame.origin.y += d;
		cellFrame.size.height -= 2*d;
	}
	if (_statusImage)
		cellFrame.size.width -= [_statusImage size].width;
	cellFrame.size.width -= 4;
	cellFrame.origin.x += 2;
	[[self attributedStringValue] drawInRect:cellFrame];
}

- (NSSize)cellSize
{
	NSSize cellSize = [super cellSize];
	cellSize.width += (self.image ? [self.image size].width : 0) + (_statusImage ? [_statusImage size].width : 0) + 4;
	return cellSize;
}

@end

