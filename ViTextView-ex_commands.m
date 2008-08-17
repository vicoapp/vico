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

- (void)ex_wq:(ExCommand *)command
{
	[self ex_write:command];
	[self ex_quit:command];
}

- (void)ex_xit:(ExCommand *)command
{
	[self ex_write:command];
	[self ex_quit:command];
}

- (void)ex_edit:(ExCommand *)command
{
	NSString *file = [command.arguments objectAtIndex:0];
	if(file)
		[[self delegate] newTabWithURL:[NSURL fileURLWithPath:file]];
	else
		[[self delegate] newTabWithURL:nil];
}

@end
