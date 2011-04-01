#import "MHTextIconCell.h"

@implementation MHTextIconCell

@synthesize image;

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSSize size = NSMakeSize(0, 0);

	if (image) {
		size = [image size];

		NSRect imgRect;
		imgRect.origin = cellFrame.origin;
		imgRect.origin.x += 4;
		if (cellFrame.size.height > size.height)
			imgRect.origin.y += (cellFrame.size.height - size.height) / 2.0;
		imgRect.size = size;
		[image setFlipped:YES];
		[image drawInRect:imgRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	}

	NSRect textRect = cellFrame;
	if (image) {
		textRect.origin.x += size.width + 6;
		textRect.size.width -= size.width + 6;
		if (cellFrame.size.height > [[self font] pointSize])
			textRect.origin.y += (cellFrame.size.height - [[self font] pointSize]) / 3.0;
	}
	[super drawInteriorWithFrame:textRect inView:controlView];
}

@end

