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

- (void)ex_cd:(ExCommand *)command
{
	NSString *path = command.filename;
	if (path == nil)
		path = @"~";
	if (![[NSFileManager defaultManager] changeCurrentDirectoryPath:[path stringByExpandingTildeInPath]])
	{
		[[self delegate] message:@"Error: %@: Failed to change directory.", path];
	}
}

- (void)ex_edit:(ExCommand *)command
{
	if (command.filename == nil)
	{
		[[self delegate] openFileInTab:nil];
	}
	else
	{
		NSString *path = command.filename;
		if ([command.filename hasPrefix:@"~"])
			path = [command.filename stringByExpandingTildeInPath];
		else if (![command.filename hasPrefix:@"/"])
			path = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:command.filename];
		[[self delegate] openFileInTab:path];
	}
}

@end
