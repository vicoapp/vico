#import "ViSeparatorCell.h"

@implementation ViSeparatorCell

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	[[NSColor colorWithCalibratedWhite:2.0/3.0 alpha:0.5] set];
	NSBezierPath *path = [[NSBezierPath alloc] init];
	CGFloat x = 2; //NSMinX(cellFrame);
	CGFloat y = NSMinY(cellFrame) + NSHeight(cellFrame)/2.0;
	[path moveToPoint:NSMakePoint(x, y)];
	[path lineToPoint:NSMakePoint(NSWidth([controlView frame]) - 2, y)];
	[path setLineWidth:0];
	[path stroke];
	[path release];
}

@end

