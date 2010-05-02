#import "ViBgView.h"

@implementation ViBgView

@synthesize sourceHighlight;

- (void)drawRect:(NSRect)rect
{
	rect = [self bounds];
	if (sourceHighlight)
		[[NSColor colorWithDeviceRed:(float)0xDD/0xFF green:(float)0xE4/0xFF blue:(float)0xEB/0xFF alpha:1.0] set];
	else
		[[NSColor colorWithDeviceRed:(float)0xED/0xFF green:(float)0xED/0xFF blue:(float)0xED/0xFF alpha:1.0] set];
	[NSBezierPath fillRect: rect];
}

@end

