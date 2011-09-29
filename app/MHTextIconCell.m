#import "MHTextIconCell.h"
#include "logging.h"

/*
 * http://developer.apple.com/library/mac/#samplecode/ImageBackground/Introduction/Intro.html
 */

@implementation MHTextIconCell

@synthesize image = _image;
@synthesize modified = _modified;
@synthesize statusImage = _statusImage;
@synthesize modImage = _modImage;

- (void)dealloc
{
	[_image release];
	[_modImage release];
	[_statusImage release];
	[super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
	// NSCopyObject() horror story!?
	// http://robnapier.net/blog/implementing-nscopying-439
	MHTextIconCell *copy = (MHTextIconCell *)[super copyWithZone:zone];
        // Why do we have to refer to the instance variables directly?
        // Why can't we use [copy setImage:]?
	copy->_image = [_image retain];
	copy->_modified = _modified;
	copy->_statusImage = [_statusImage retain];
	copy->_modImage = [_modImage retain];
	return copy;
}

- (void)editWithFrame:(NSRect)aRect
               inView:(NSView *)controlView
               editor:(NSText *)textObj
             delegate:(id)anObject
                event:(NSEvent *)theEvent
{
	NSRect textFrame, imageFrame;
	NSDivideRect(aRect, &imageFrame, &textFrame, 4 + [_image size].width, NSMinXEdge);
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
	NSDivideRect(aRect, &imageFrame, &textFrame, 4 + [_image size].width, NSMinXEdge);
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
	NSRect imageFrame;

	if (_image != nil) {
		imageSize = [_image size];
		NSDivideRect(cellFrame, &imageFrame, &cellFrame, 4 + imageSize.width, NSMinXEdge);
		if ([self drawsBackground]) {
			[[self backgroundColor] set];
			NSRectFill(imageFrame);
		}
		imageFrame.origin.x += 3;
		imageFrame.size = imageSize;

		if ([controlView isFlipped])
			imageFrame.origin.y += ceil((cellFrame.size.height + imageFrame.size.height) / 2);
		else
			imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);

		[_image compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
	}

	if (_statusImage != nil) {
		imageSize = [_statusImage size];
		NSPoint p = NSMakePoint(NSMaxX(cellFrame) - imageSize.width, cellFrame.origin.y);
		p.y += ceil((cellFrame.size.height + imageSize.height) / 2);
		[_statusImage compositeToPoint:p operation:NSCompositeSourceOver];
	}

	if (_modified) {
		if (_modImage == nil)
			_modImage = [[NSImage imageNamed:NSImageNameStatusPartiallyAvailable] retain];
		NSPoint modPoint = cellFrame.origin;
		NSSize modImageSize = [_modImage size];
		modPoint.y += ceil((cellFrame.size.height + modImageSize.height) / 2);
		modPoint.x = imageFrame.origin.x - modImageSize.width;
		[_modImage compositeToPoint:modPoint operation:NSCompositeSourceOver];
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
	cellSize.width += (_image ? [_image size].width : 0) + (_statusImage ? [_statusImage size].width : 0) + 4;
	return cellSize;
}

@end

