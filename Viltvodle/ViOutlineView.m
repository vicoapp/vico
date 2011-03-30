#import "ViOutlineView.h"
#import "NSEvent-keyAdditions.h"
#import "ViError.h"
#include "logging.h"

@implementation ViOutlineView

- (void)awakeFromNib
{
	keyManager = [[ViKeyManager alloc] initWithTarget:[self delegate]
					       defaultMap:[ViMap explorerMap]];
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
	if ([[self window] firstResponder] != self)
		return NO;
	return [keyManager performKeyEquivalent:theEvent];
}

- (void)keyDown:(NSEvent *)theEvent
{
	[keyManager keyDown:theEvent];
}

@end
