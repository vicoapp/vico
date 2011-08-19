#import "ViWindow.h"
#import "ViCommon.h"

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

- (BOOL)isFullScreen
{
	return ([self styleMask] & NSFullScreenWindowMask) == NSFullScreenWindowMask;
}

@end
