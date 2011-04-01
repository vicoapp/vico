#import "ViSplitView.h"

@implementation ViSplitView

- (NSColor *)dividerColor
{
	return [NSColor grayColor];
}

- (void)drawDividerInRect:(NSRect)aRect
{
	NSRect bg = aRect;
	bg.size.height = 22;
	NSDrawWindowBackground(bg);
	[[NSColor colorWithCalibratedWhite:0.3 alpha:0.2] set];
	NSRectFillUsingOperation(bg, NSCompositeSourceAtop);

	NSBezierPath *bezier = [NSBezierPath bezierPath];
	[bezier moveToPoint:NSMakePoint(bg.origin.x, 0.5)];
	[bezier lineToPoint:NSMakePoint(bg.origin.x + bg.size.width, 0.5)];
	[bezier moveToPoint:NSMakePoint(bg.origin.x, bg.size.height - 0.5)];
	[bezier lineToPoint:NSMakePoint(bg.origin.x + bg.size.width, bg.size.height - 0.5)];
	[[NSColor darkGrayColor] set];
	[bezier stroke];

	aRect.origin.y += 22;
	aRect.size.height -= 22;

	[super drawDividerInRect:aRect];
}

@end

