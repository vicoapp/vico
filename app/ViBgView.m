#import "ViBgView.h"

@implementation ViBgView

@synthesize backgroundColor;

- (void)drawRect:(NSRect)rect
{
	if (backgroundColor) {
		[backgroundColor set];
		NSRectFill([self bounds]);
	}
}

@end

