#import "ViBgView.h"

@implementation ViBgView

@synthesize sourceHighlight;

- (void)drawRect:(NSRect)rect
{
	if (sourceHighlight) {
		[[NSColor colorWithDeviceRed:(float)0xDD/0xFF green:(float)0xE4/0xFF blue:(float)0xEB/0xFF alpha:1.0] set];
		NSRectFill([self bounds]);
	}
}

@end

