#import "ViCompletionView.h"
#import "NSEvent-keyAdditions.h"
#import "ViError.h"
#include "logging.h"

@implementation ViCompletionView

@synthesize keyManager;

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
