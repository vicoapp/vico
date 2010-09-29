#import "MHTextIconCell.h"

@implementation MHTextIconCell

@synthesize image;

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSSize size = [image size];
	NSRect imgRect;
	imgRect.origin = cellFrame.origin;
	imgRect.origin.x += 4;
	imgRect.origin.y += 2;
	imgRect.size = size;
//	if (imgRect.size.height < cellFrame.size.height)
//		imgRect.size.height += (cellFrame.size.height - size.height) / 2;
	[image setFlipped:YES];
	[image drawInRect:imgRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	NSRect textRect = NSMakeRect(cellFrame.origin.x + size.width+6, cellFrame.origin.y + 3.5, cellFrame.size.width - size.width+6, cellFrame.size.height);
	[super drawInteriorWithFrame:textRect inView:controlView];
}

@end
