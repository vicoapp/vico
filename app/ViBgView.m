#import "ViBgView.h"
#include "logging.h"

@implementation ViBgView

@synthesize backgroundColor = _backgroundColor;

- (void)drawRect:(NSRect)rect
{
	if (_backgroundColor) {
		[_backgroundColor set];
		NSRectFill([self bounds]);
	}
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	[_backgroundColor release];
	[super dealloc];
}

@end

