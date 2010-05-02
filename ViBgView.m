#import "ViBgView.h"

@implementation ViBgView

- (void)drawRect:(NSRect)rect
{
	rect = [self bounds];
	//[[NSColor colorWithDeviceRed:(float)0xDD/0xFF green:(float)0xE4/0xFF blue:(float)0xEB/0xFF alpha:1.0] set];
	[[NSColor windowBackgroundColor] set];
	[NSBezierPath fillRect: rect];
}

@end

