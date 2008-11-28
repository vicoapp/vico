#import "ViSeparatorCell.h"

@implementation ViSeparatorCell

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	[[NSColor lightGrayColor] set];
	NSBezierPath *path = [[NSBezierPath alloc] init];
	[path moveToPoint:NSMakePoint(NSMinX(cellFrame) + 10, NSMinY(cellFrame) + NSHeight(cellFrame)/2)];
	[path lineToPoint:NSMakePoint(NSMinX(cellFrame) + NSWidth(cellFrame) - 20, NSMinY(cellFrame) + NSHeight(cellFrame)/2)];
	[path stroke];
}

@end

