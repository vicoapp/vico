#import "ViTextView.h"
#import "ViEditController.h"
#import "ExCommand.h"

@implementation ViTextView (ex_commands)

- (void)ex_write:(ExCommand *)command
{
	[[self delegate] save];
}

- (void)ex_quit:(ExCommand *)command
{
	[NSApp terminate:self];
}

@end
