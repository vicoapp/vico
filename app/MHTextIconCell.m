#import "MHTextIconCell.h"
#include "logging.h"

/*
 * http://developer.apple.com/library/mac/#samplecode/ImageBackground/Introduction/Intro.html
 */

@implementation MHTextIconCell

@synthesize image;
@synthesize modified;

- (void)editWithFrame:(NSRect)aRect
               inView:(NSView *)controlView
               editor:(NSText *)textObj
             delegate:(id)anObject
                event:(NSEvent *)theEvent
{
	NSRect textFrame, imageFrame;
	NSDivideRect(aRect, &imageFrame, &textFrame, 4 + [image size].width, NSMinXEdge);
	CGFloat d = (aRect.size.height - [[self font] pointSize]) / 3.0;
	textFrame.origin.y += d;
	textFrame.size.height -= 2*d;
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
	NSDivideRect(aRect, &imageFrame, &textFrame, 4 + [image size].width, NSMinXEdge);
	CGFloat d = (aRect.size.height - [[self font] pointSize]) / 3.0;
	textFrame.origin.y += d;
	textFrame.size.height -= 2*d;
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

	if (image != nil) {

		imageSize = [image size];
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

		[image compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
	}

	if (modified) {
		if (modImage == nil) {
			modImage = [NSImage imageNamed:NSImageNameStatusPartiallyAvailable];
			modImageSize = [modImage size];
		}
		NSPoint modPoint = cellFrame.origin;
		modPoint.y += ceil((cellFrame.size.height + modImageSize.height) / 2);
		modPoint.x = imageFrame.origin.x - modImageSize.width;
		[modImage compositeToPoint:modPoint operation:NSCompositeSourceOver];
	}

	CGFloat d = (cellFrame.size.height - [[self font] pointSize]) / 3.0;
	cellFrame.origin.y += d;
	cellFrame.size.height -= 2*d;
	[super drawWithFrame:cellFrame inView:controlView];
}

- (NSSize)cellSize
{
	NSSize cellSize = [super cellSize];
	cellSize.width += (image ? [image size].width : 0) + 4;
	return cellSize;
}

@end

