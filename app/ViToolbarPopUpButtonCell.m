#import "ViToolbarPopUpButtonCell.h"
#import "logging.h"

@implementation ViToolbarPopUpButtonCell

- (void)setImage:(NSImage *)anImage
{
	_image = [anImage retain];
	[_image setFlipped:YES];
}

- (void)dealloc
{
	[_image release];
	[super dealloc];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSSize sz = [_image size];
	NSPoint p = NSMakePoint((cellFrame.size.width - sz.width) / 2.0,
	                        (cellFrame.size.height - sz.height) / 2.0);
	[_image drawAtPoint:p fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
}

@end
