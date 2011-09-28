#import "ViWindow.h"
#import "ViCommon.h"
#include "logging.h"

@implementation ViWindow

- (BOOL)makeFirstResponder:(NSResponder *)responder
{
	if ([super makeFirstResponder:responder]) {
		NSNotification *notification = [NSNotification notificationWithName:ViFirstResponderChangedNotification object:responder];
		NSNotificationCoalescing mask = NSNotificationCoalescingOnSender | NSNotificationCoalescingOnName; 
		[[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostNow coalesceMask:mask forModes:nil];
		return YES;
	}

	return NO;
}

DEBUG_FINALIZE();

- (void)dealloc
{
	DEBUG_DEALLOC();
	[super dealloc];
}

- (BOOL)isFullScreen
{
	return ([self styleMask] & NSFullScreenWindowMask) == NSFullScreenWindowMask;
}

- (id)firstResponderOrDelegate
{
	id resp = [self firstResponder];
	if ([resp isKindOfClass:[NSTextView class]] && resp == [self fieldEditor:NO forObject:nil] != nil)
		resp = [(NSTextView *)resp delegate];
	return resp;
}

@end
