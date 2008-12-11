#import "ViTextView.h"
#import "ViDocument.h"
#import "ExCommand.h"
#import "ViAppController.h"

@implementation ViTextView (ex_commands)

- (void)ex_write:(ExCommand *)command
{
	[[self delegate] saveDocument:self];
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
		[[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:nil];
	}
	else
	{
		NSString *path = command.filename;
		if ([command.filename hasPrefix:@"~"])
			path = [command.filename stringByExpandingTildeInPath];
		else if (![command.filename hasPrefix:@"/"])
			path = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:command.filename];
		[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:path] display:YES error:nil];
	}
}

- (void)ex_bang:(ExCommand *)command
{
}

- (void)ex_set:(ExCommand *)command
{
	NSDictionary *variables = [NSDictionary dictionaryWithObjectsAndKeys:
		@"shiftwidth", @"sw",
		@"autoindent", @"ai",
		@"expandtab", @"et",
		@"ignorecase", @"ic",
		@"tabstop", @"ts",
		@"number", @"nu",
		@"number", @"num",
		@"number", @"numb",
		@"autocollapse", @"ac",  // automatically collapses other documents in the symbol list
		@"hidetab", @"ht",  // hide tab bar for single tabs
		nil];

	NSArray *booleans = [NSArray arrayWithObjects:@"autoindent", @"expandtab", @"ignorecase", @"number", @"autocollapse", @"hidetab", nil];
	static NSString *usage = @"usage: se[t] [option[=[value]]...] [nooption ...] [option? ...] [all]";

	NSString *var;
	for (var in command.words)
	{
		NSUInteger equals = [var rangeOfString:@"="].location;
		NSUInteger qmark = [var rangeOfString:@"?"].location;
		if (equals == 0 || qmark == 0)
		{
			[[self delegate] message:usage];
			return;
		}
		
		NSString *name;
		if (equals != NSNotFound)
			name = [var substringToIndex:equals];
		else if (qmark != NSNotFound)
			name = [var substringToIndex:qmark];
		else
			name = var;

		BOOL turnoff = NO;
		if ([name hasPrefix:@"no"])
		{
			name = [name substringFromIndex:2];
			turnoff = YES;
		}

		if ([name isEqualToString:@"all"])
		{
			[[self delegate] message:@"'set all' not implemented."];
			return;
		}

		NSString *defaults_name = [variables objectForKey:name];
		if (defaults_name == nil && [[variables allValues] containsObject:name])
			defaults_name = name;
			
		if (defaults_name == nil)
		{
			[[self delegate] message:@"set: no %@ option: 'set all' gives all option values.", name];
			return;
		}

		if (qmark != NSNotFound)
		{
			if ([booleans containsObject:defaults_name])
			{
				int val = [[NSUserDefaults standardUserDefaults] integerForKey:defaults_name];
				[[self delegate] message:[NSString stringWithFormat:@"%@%@", val == NSOffState ? @"no" : @"", defaults_name]];
			}
			else
			{
				NSString *val = [[NSUserDefaults standardUserDefaults] stringForKey:defaults_name];
				[[self delegate] message:[NSString stringWithFormat:@"%@=%@", defaults_name, val]];
			}
			continue;
		}
		
		if ([booleans containsObject:defaults_name])
		{
			if (equals != NSNotFound)
			{
				[[self delegate] message:@"set: [no]%@ option doesn't take a value", defaults_name];
				return;
			}
			
			[[NSUserDefaults standardUserDefaults] setInteger:turnoff ? NSOffState : NSOnState forKey:defaults_name];

			// Special handling, FIXME: replace with KVC observers!
			if ([defaults_name isEqualToString:@"number"])
			{
				[[self delegate] enableLineNumbers:!turnoff];
			}
		}
		else
		{
			if (equals == NSNotFound)
			{
				NSString *val = [[NSUserDefaults standardUserDefaults] stringForKey:defaults_name];
				[[self delegate] message:[NSString stringWithFormat:@"%@=%@", defaults_name, val]];
			}
			else
			{
				NSString *val = [var substringFromIndex:equals + 1];
				[[NSUserDefaults standardUserDefaults] setObject:val forKey:defaults_name];
				
				// Special handling, FIXME: replace with KVC observers!
				if ([defaults_name isEqualToString:@"tabstop"])
				{
                                        [self setTabSize:[[NSUserDefaults standardUserDefaults] integerForKey:@"tabstop"]];
                                }
			}
		}
	}
}

@end
