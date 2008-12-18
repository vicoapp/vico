#import "MHTextIconCell.h"

@implementation MHTextIconCell

@synthesize image;

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSSize size = [image size];
	NSRect imgRect;
	imgRect.origin = cellFrame.origin;
	imgRect.origin.x += 1; // two pixels space around width
	imgRect.size = size;
	if (imgRect.size.height < cellFrame.size.height)
		imgRect.size.height += (cellFrame.size.height - size.height) / 2;
	[image setFlipped:YES];
	[image drawInRect:imgRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	NSRect textRect = NSMakeRect(cellFrame.origin.x + size.width+4, cellFrame.origin.y, cellFrame.size.width - size.width+4, cellFrame.size.height);
	[super drawInteriorWithFrame:textRect inView:controlView];
}

@end
