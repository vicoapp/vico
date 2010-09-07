#import "ViTextView.h"
#import "ViDocument.h"
#import "ExCommand.h"
#import "ViAppController.h"
#import "NSTextStorage-additions.h"

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
        ViWindowController *windowController = [[self document] windowController];
	if (![windowController changeCurrentDirectory:[path stringByExpandingTildeInPath]])
		[[self delegate] message:@"Error: %@: Failed to change directory.", path];
        else
		[[self delegate] message:@"%@", [windowController currentDirectory]];
}

- (void)ex_pwd:(ExCommand *)command
{
	ViWindowController *windowController = [[self document] windowController];
	[[self delegate] message:@"%@", [windowController currentDirectory]];
}

- (void)ex_edit:(ExCommand *)command
{
	ViWindowController *windowController = [[self document] windowController];

	INFO(@"command.filename == %@", command.filename);

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
                {
			path = [[windowController currentDirectory] stringByAppendingPathComponent:command.filename];
                }
		BOOL isDirectory = NO;
		if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory])
		{
			if (isDirectory)
			{
				[[self delegate] message:@"Can't edit directory %@", path];
			}
			else
			{
                                ViDocument *document;
				document = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:path]
				                                                                                  display:YES
				                                                                                    error:nil];
                                if (document)
                                        [windowController selectDocument:document];
			}
		}
		else
		{
			id doc = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:nil];
			[doc setFileURL:[NSURL fileURLWithPath:path]];
		}
	}
}

- (void)ex_bang:(ExCommand *)command
{
}

- (void)ex_number:(ExCommand *)command
{
	NSUInteger line;

	if (command.addr2->type == EX_ADDR_ABS) {
		line = command.addr2->addr.abs.line;
	} else if (command.addr1->type == EX_ADDR_ABS) {
		line = command.addr1->addr.abs.line;
	} else {
		[[self delegate] message:@"Not implemented."];
		return;
	}

	NSInteger location = [[self textStorage] locationForStartOfLine:line];
	if (location == -1)
		[[self delegate] message:@"Movement past the end-of-file"];
	else {
		[self setCaret:location];
		[self scrollToCaret];

	}
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
			}
		}
	}
}

@end
