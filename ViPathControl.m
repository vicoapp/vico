#import "ViPathControl.h"
#import "logging.h"

@implementation ViPathControl

- (void)drawRect:(NSRect)dirtyRect
{
	NSRect bg = dirtyRect;
	//bg.size.width += 1;
	NSDrawWindowBackground(bg);
	[[NSColor colorWithCalibratedWhite:0.3 alpha:0.2] set];
	NSRectFillUsingOperation(bg, NSCompositeSourceAtop);

	NSRect frame = [self frame];
	NSBezierPath *bezier = [NSBezierPath bezierPath];
	[bezier moveToPoint:NSMakePoint(frame.origin.x, 0.5)];
	[bezier lineToPoint:NSMakePoint(frame.origin.x + frame.size.width, 0.5)];
	[bezier moveToPoint:NSMakePoint(frame.origin.x, frame.size.height - 0.5)];
	[bezier lineToPoint:NSMakePoint(frame.origin.x + frame.size.width, frame.size.height - 0.5)];
	[[NSColor darkGrayColor] set];
	[bezier stroke];

	[super drawRect:dirtyRect];
}

@end

