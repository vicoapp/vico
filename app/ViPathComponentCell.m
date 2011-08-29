#import "ViPathComponentCell.h"
#include "logging.h"

@implementation ViPathComponentCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSBezierPath *path = [NSBezierPath bezierPath];

	if (cellFrame.size.width >= 22) {
		[path setLineWidth:3.0];
		[[[NSColor whiteColor] colorWithAlphaComponent:0.8] set];
		[path moveToPoint:NSMakePoint(NSMaxX(cellFrame) - 7.5, NSMaxY(cellFrame))];
                [path lineToPoint:NSMakePoint(NSMaxX(cellFrame), cellFrame.origin.y + cellFrame.size.height / 2.0)];
                [path lineToPoint:NSMakePoint(NSMaxX(cellFrame) - 7.5, cellFrame.origin.y)];
		[path stroke];

		path = [NSBezierPath bezierPath];
		[path setLineWidth:1.0];
		[[[NSColor grayColor] colorWithAlphaComponent:0.7] set];
		[path moveToPoint:NSMakePoint(NSMaxX(cellFrame) - 7.5, NSMaxY(cellFrame))];
		[path lineToPoint:NSMakePoint(NSMaxX(cellFrame), cellFrame.origin.y + cellFrame.size.height / 2.0)];
		[path lineToPoint:NSMakePoint(NSMaxX(cellFrame) - 7.5, cellFrame.origin.y)];
		[path stroke];
	} else if ([self isHighlighted]) {
		[path moveToPoint:NSMakePoint(NSMaxX(cellFrame), NSMaxY(cellFrame))];
		[path lineToPoint:NSMakePoint(NSMaxX(cellFrame), cellFrame.origin.y)];
	}

	if ([self isHighlighted]) {
		[path lineToPoint:NSMakePoint(cellFrame.origin.x - 7.5, cellFrame.origin.y)];
		[path lineToPoint:NSMakePoint(cellFrame.origin.x, cellFrame.origin.y + cellFrame.size.height / 2.0)];
		[path lineToPoint:NSMakePoint(cellFrame.origin.x - 7.5, NSMaxY(cellFrame))];
		[[[NSColor grayColor] colorWithAlphaComponent:0.8] set];
		[path fill];
	}

	cellFrame.origin.x -= 2;
	cellFrame.size.width -= 5;
	[self drawInteriorWithFrame:cellFrame inView:controlView];
}

@end
