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

- (IBAction)closeCurrent:(id)sender
{
	[[self windowController] closeCurrent:sender];
}

- (IBAction)closeCurrentDocument:(id)sender
{
	[[self windowController] closeCurrentDocument:sender];
}

- (IBAction)selectNextTab:(id)sender
{
	[[self windowController] selectNextTab:sender];
}

- (IBAction)selectPreviousTab:(id)sender
{
	[[self windowController] selectPreviousTab:sender];
}

- (BOOL)isFullScreen
{
	return ([self styleMask] & NSFullScreenWindowMask) == NSFullScreenWindowMask;
}

@end
