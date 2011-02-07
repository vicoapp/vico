#import "ViWindow.h"
#import "ViCommon.h"
#import "logging.h"

@implementation ViWindow

- (BOOL)makeFirstResponder:(NSResponder *)responder
{
	INFO(@"making first responder: %@", responder);

	if ([super makeFirstResponder:responder]) {
		NSNotification *notification = [NSNotification notificationWithName:ViFirstResponderChangedNotification object:responder];
		NSNotificationCoalescing mask = NSNotificationCoalescingOnSender | NSNotificationCoalescingOnName; 
		[[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostNow coalesceMask:mask forModes:nil];
		return YES;
	}

	return NO;
}

@end
