#import "ViCompletionView.h"
#import "NSEvent-keyAdditions.h"
#import "ViError.h"
#include "logging.h"

@implementation ViCompletionView

@synthesize keyManager = _keyManager;

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
	if ([[self window] firstResponder] != self)
		return NO;
	return [_keyManager performKeyEquivalent:theEvent];
}

- (void)keyDown:(NSEvent *)theEvent
{
	[_keyManager keyDown:theEvent];
}

@end
