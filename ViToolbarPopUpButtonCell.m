#import "ViToolbarPopUpButtonCell.h"
#import "logging.h"

@implementation ViToolbarPopUpButtonCell

- (void)setImage:(NSImage *)anImage
{
	image = anImage;
	[image setFlipped:YES];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSSize sz = [image size];
	NSPoint p = NSMakePoint((cellFrame.size.width - sz.width) / 2.0,
	                        (cellFrame.size.height - sz.height) / 2.0);
	[image drawAtPoint:p fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
}

@end
