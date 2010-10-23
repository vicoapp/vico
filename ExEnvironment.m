#import "ExEnvironment.h"
#import "ExCommand.h"
#import "ViTheme.h"
#import "ViThemeStore.h"
#import "ViTextView.h"
#import "ViWindowController.h"
#import "NSTextStorage-additions.h"
#include "logging.h"

@interface ExEnvironment (private)
- (BOOL)changeCurrentDirectory:(NSString *)path;
- (NSString *)filenameAtLocation:(NSUInteger)aLocation inFieldEditor:(NSText *)fieldEditor range:(NSRange *)outRange;
- (unsigned)completePath:(NSString *)partialPath intoString:(NSString **)longestMatchPtr matchesIntoArray:(NSArray **)matchesPtr;
- (void)displayCompletions:(NSArray *)completions forPath:(NSString *)path;
@end

@implementation ExEnvironment

@synthesize currentDirectory;

- (id)init
{
	self = [super init];
	if (self) {
		exCommandHistory = [[NSMutableArray alloc] init];
                [self changeCurrentDirectory:[[NSFileManager defaultManager] currentDirectoryPath]];
	}
	return self;
}

- (void)awakeFromNib
{
	[statusbar setFont:[NSFont userFixedPitchFontOfSize:12.0]];
	[statusbar setDelegate:self];

	[commandSplit setPosition:NSHeight([commandSplit frame]) ofDividerAtIndex:0];
	[commandOutput setFont:[NSFont userFixedPitchFontOfSize:10.0]];
}

- (BOOL)changeCurrentDirectory:(NSString *)path
{
        NSString *p;
        if ([path isAbsolutePath])
                p = [path stringByStandardizingPath];
        else
                p = [[[self currentDirectory] stringByAppendingPathComponent:path] stringByStandardizingPath];

        BOOL isDirectory = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:p isDirectory:&isDirectory] && isDirectory) {
                currentDirectory = p;
                return YES;
        } else {
                INFO(@"failed to set current directory to '%@'", p);
                return NO;
        }
}

- (BOOL)control:(NSControl *)sender textView:(NSTextView *)textView doCommandBySelector:(SEL)aSelector
{
	if (sender == statusbar)
	{
		NSText *fieldEditor = [window fieldEditor:NO forObject:sender];
		if (aSelector == @selector(cancelOperation:) || // escape
		    aSelector == @selector(noop:) ||            // ctrl-c and ctrl-g ...
		    aSelector == @selector(insertNewline:) ||
		    (aSelector == @selector(deleteBackward:) && [fieldEditor selectedRange].location == 0))
		{
			[commandSplit setPosition:NSHeight([commandSplit frame]) ofDividerAtIndex:0];
			if (aSelector != @selector(insertNewline:))
				[statusbar setStringValue:@""];
			[[statusbar target] performSelector:[statusbar action] withObject:self];
			return YES;
		}
		else if (aSelector == @selector(moveUp:))
		{
			INFO(@"%s", "look back in history");
			return YES;
		}
		else if (aSelector == @selector(moveDown:))
		{
			INFO(@"%s", "look forward in history");
			return YES;
		}
		else if (aSelector == @selector(insertBacktab:))
		{
			return YES;
		}
		else if (aSelector == @selector(insertTab:) ||
		         aSelector == @selector(deleteForward:)) // ctrl-d
		{
			NSUInteger caret = [fieldEditor selectedRange].location;
			NSRange range;
			NSString *filename = [self filenameAtLocation:caret inFieldEditor:fieldEditor range:&range];

			if (![filename isAbsolutePath])
				filename = [[self currentDirectory] stringByAppendingPathComponent:filename];
                        filename = [[filename stringByStandardizingPath] stringByAbbreviatingWithTildeInPath];

                        if ([filename isEqualToString:@"~"])
                                filename = @"~/";

			NSArray *completions = nil;
			NSString *completion = nil;
			NSUInteger num = [self completePath:filename intoString:&completion matchesIntoArray:&completions];
	
			if (completion) {
				NSMutableString *s = [[NSMutableString alloc] initWithString:[fieldEditor string]];
				[s replaceCharactersInRange:range withString:completion];
				[fieldEditor setString:s];
			}

			if (num == 1 && [completion hasSuffix:@"/"]) {
				/* If only one directory match, show completions inside that directory. */
				num = [self completePath:completion intoString:&completion matchesIntoArray:&completions];
			}

			if (num > 1)
				[self displayCompletions:completions forPath:completion];

			return YES;
		}
	}
	return NO;
}

- (NSString *)filenameAtLocation:(NSUInteger)aLocation inFieldEditor:(NSText *)fieldEditor range:(NSRange *)outRange
{
	NSString *s = [fieldEditor string];
	NSRange r = [s rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]
				       options:NSBackwardsSearch
					 range:NSMakeRange(0, aLocation)];

	if (r.location++ == NSNotFound)
		r.location = 0;

	r.length = aLocation - r.location;
	*outRange = r;

	return [s substringWithRange:r];
}

- (unsigned)completePath:(NSString *)partialPath intoString:(NSString **)longestMatchPtr matchesIntoArray:(NSArray **)matchesPtr
{
	NSFileManager *fm = [NSFileManager defaultManager];

	NSString *path;
	NSString *suffix;
	if ([partialPath hasSuffix:@"/"])
	{
		path = partialPath;
		suffix = @"";
	}
	else
	{
		path = [partialPath stringByDeletingLastPathComponent];
		suffix = [partialPath lastPathComponent];
	}

	NSArray *directoryContents = [fm directoryContentsAtPath:[path stringByExpandingTildeInPath]];
	NSMutableArray *matches = [[NSMutableArray alloc] init];
	NSString *entry;
	for (entry in directoryContents)
	{
		if ([entry compare:suffix options:NSCaseInsensitiveSearch range:NSMakeRange(0, [suffix length])] == NSOrderedSame)
		{
			if ([entry hasPrefix:@"."] && ![suffix hasPrefix:@"."])
				continue;
			NSString *s = [path stringByAppendingPathComponent:entry];
			BOOL isDirectory = NO;
			if ([fm fileExistsAtPath:[s stringByExpandingTildeInPath] isDirectory:&isDirectory] && isDirectory)
				[matches addObject:[s stringByAppendingString:@"/"]];
			else
				[matches addObject:s];
		}
	}

	if (longestMatchPtr && [matches count] > 0)
	{
		NSString *longestMatch = nil;
		NSString *firstMatch = [matches objectAtIndex:0];
		NSString *m;
		for (m in matches)
		{
			NSString *commonPrefix = [firstMatch commonPrefixWithString:m options:NSCaseInsensitiveSearch];
			if (longestMatch == nil || [commonPrefix length] < [longestMatch length])
				longestMatch = commonPrefix;
		}
		*longestMatchPtr = longestMatch;
	}

	if (matchesPtr)
		*matchesPtr = matches;

	return [matches count];
}

- (void)displayCompletions:(NSArray *)completions forPath:(NSString *)path
{
	int skipIndex;
	if ([path hasSuffix:@"/"])
		skipIndex = [path length];
	else
		skipIndex = [[path stringByDeletingLastPathComponent] length] + 1;

	NSDictionary *attrs = [NSDictionary dictionaryWithObject:[NSFont userFixedPitchFontOfSize:11.0]
							  forKey:NSFontAttributeName];
	NSString *c;
	NSSize maxsize = NSMakeSize(0, 0);
	for (c in completions)
	{
		NSSize size = [[c substringFromIndex:skipIndex] sizeWithAttributes:attrs];
		if (size.width > maxsize.width)
			maxsize = size;
	}

	CGFloat colsize = maxsize.width + 50;

	NSRect bounds = [commandOutput bounds];
	int columns = NSWidth(bounds) / colsize;
	if (columns <= 0)
		columns = 1;

	// remove all previous tab stops
	NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	NSTextTab *tabStop;
	for (tabStop in [style tabStops])
	{
		[style removeTabStop:tabStop];
	}
	[style setDefaultTabInterval:colsize];

	[[[commandOutput textStorage] mutableString] setString:@""];
	int n = 0;
	for (c in completions)
	{
		[[[commandOutput textStorage] mutableString] appendFormat:@"%@%@",
			[c substringFromIndex:skipIndex], (++n % columns) == 0 ? @"\n" : @"\t"];
	}

	ViTheme *theme = [[ViThemeStore defaultStore] defaultTheme];
	[commandOutput setBackgroundColor:[theme backgroundColor]];
	[commandOutput setSelectedTextAttributes:[NSDictionary dictionaryWithObject:[theme selectionColor]
								             forKey:NSBackgroundColorAttributeName]];
	attrs = [NSDictionary dictionaryWithObjectsAndKeys:
			style, NSParagraphStyleAttributeName,
			[theme foregroundColor], NSForegroundColorAttributeName,
			[theme backgroundColor], NSBackgroundColorAttributeName,
			[NSFont userFixedPitchFontOfSize:11.0], NSFontAttributeName,
			nil];
	[[commandOutput textStorage] addAttributes:attrs range:NSMakeRange(0, [[commandOutput textStorage] length])];

        // display the completion by expanding the commandSplit view
	[commandSplit setPosition:NSHeight([commandSplit frame])*0.60 ofDividerAtIndex:0];
}

- (IBAction)finishedExCommand:(id)sender
{
	NSString *exCommand = [statusbar stringValue];
	[statusbar setStringValue:@""];
	[statusbar setEditable:NO];
	[statusbar setHidden:YES];
	[messageField setHidden:NO];
	[window makeFirstResponder:exTextView];
	if ([exCommand length] == 0)
		return;

	[exDelegate performSelector:exCommandSelector withObject:exCommand withObject:exContextInfo];
	exDelegate = nil;

	// add the command to the history
	NSUInteger i = [exCommandHistory indexOfObject:exCommand];
	if (i != NSNotFound)
		[exCommandHistory removeObjectAtIndex:i];
	[exCommandHistory addObject:exCommand];
}

- (void)getExCommandWithDelegate:(id)aDelegate selector:(SEL)aSelector prompt:(NSString *)aPrompt contextInfo:(void *)contextInfo
{
	[messageField setHidden:YES];
	[statusbar setHidden:NO];
	[statusbar setStringValue:aPrompt];
	[statusbar setEditable:YES];
	[statusbar setTarget:self];
	[statusbar setAction:@selector(finishedExCommand:)];
	exCommandSelector = aSelector;
	exDelegate = aDelegate;
	exContextInfo = contextInfo;
	[window makeFirstResponder:statusbar];
}

- (void)parseAndExecuteExCommand:(NSString *)exCommandString contextInfo:(void *)contextInfo
{
	if ([exCommandString length] > 0) {
		ExCommand *ex = [[ExCommand alloc] initWithString:exCommandString];
		//DEBUG(@"got ex [%@], command = [%@], method = [%@]", ex, ex.command, ex.method);
		if (ex.command == NULL)
			[self message:@"The %@ command is unknown.", ex.name];
		else {
			SEL selector = NSSelectorFromString([NSString stringWithFormat:@"%@:", ex.command->method]);
			if ([self respondsToSelector:selector])
				[self performSelector:selector withObject:ex];
			else
				[self message:@"The %@ command is not implemented.", ex.name];
		}
	}
}

- (void)executeForDocument:(ViDocument *)aDocument textView:(ViTextView *)aTextView
{
	exDocument = aDocument;
	exTextView = aTextView;
	[self getExCommandWithDelegate:self selector:@selector(parseAndExecuteExCommand:contextInfo:) prompt:@":" contextInfo:NULL];
}

- (void)message:(NSString *)fmt arguments:(va_list)ap
{
	[messageField setStringValue:[[NSString alloc] initWithFormat:fmt arguments:ap]];
}

- (void)message:(NSString *)fmt, ...
{
	va_list ap;
	va_start(ap, fmt);
	[self message:fmt arguments:ap];
	va_end(ap);
}


- (void)ex_write:(ExCommand *)command
{
	[exDocument saveDocument:self];
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
	if (![self changeCurrentDirectory:[path stringByExpandingTildeInPath]])
		[self message:@"Error: %@: Failed to change directory.", path];
        else
		[self message:@"%@", [self currentDirectory]];
}

- (void)ex_pwd:(ExCommand *)command
{
	[self message:@"%@", [self currentDirectory]];
}

- (void)ex_edit:(ExCommand *)command
{
	if (command.filename == nil)
		[[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:nil];
	else {
		NSString *path = command.filename;
		if ([command.filename hasPrefix:@"~"])
			path = [command.filename stringByExpandingTildeInPath];
		else if (![command.filename hasPrefix:@"/"])
			path = [[self currentDirectory] stringByAppendingPathComponent:command.filename];

		BOOL isDirectory = NO;
		if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory]) {
			if (isDirectory)
				[self message:@"Can't edit directory %@", path];
			else {
                                ViDocument *document;
				document = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:path]
				                                                                                  display:YES
				                                                                                    error:nil];
                                if (document)
                                        [windowController selectDocument:document];
			}
		} else {
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

	if (command.addr2->type == EX_ADDR_ABS)
		line = command.addr2->addr.abs.line;
	else if (command.addr1->type == EX_ADDR_ABS)
		line = command.addr1->addr.abs.line;
	else {
		[self message:@"Not implemented."];
		return;
	}

	NSInteger location = [[exDocument textStorage] locationForStartOfLine:line];
	if (location == -1)
		[self message:@"Movement past the end-of-file"];
	else {
		[exTextView setCaret:location];
		[exTextView scrollToCaret];
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
		@"fontsize", @"fs",
		@"fontname", @"font",
		@"showguide", @"sg",
		@"guidecolumn", @"gc",
		@"searchincr", @"searchincr",
		@"wrap", @"wrap",
		@"antialias", @"antialias",
		nil];

	NSArray *booleans = [NSArray arrayWithObjects:
	    @"autoindent", @"expandtab", @"ignorecase", @"number",
	    @"autocollapse", @"hidetab", @"showguide", @"searchincr",
	    @"wrap", @"antialias", nil];
	static NSString *usage = @"usage: se[t] [option[=[value]]...] [nooption ...] [option? ...] [all]";

	NSString *var;
	for (var in command.words) {
		NSUInteger equals = [var rangeOfString:@"="].location;
		NSUInteger qmark = [var rangeOfString:@"?"].location;
		if (equals == 0 || qmark == 0) {
			[self message:usage];
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
		if ([name hasPrefix:@"no"]) {
			name = [name substringFromIndex:2];
			turnoff = YES;
		}

		if ([name isEqualToString:@"all"]) {
			[self message:@"'set all' not implemented."];
			return;
		}

		NSString *defaults_name = [variables objectForKey:name];
		if (defaults_name == nil && [[variables allValues] containsObject:name])
			defaults_name = name;

		if (defaults_name == nil) {
			[self message:@"set: no %@ option: 'set all' gives all option values.", name];
			return;
		}

		if (qmark != NSNotFound) {
			if ([booleans containsObject:defaults_name]) {
				int val = [[NSUserDefaults standardUserDefaults] integerForKey:defaults_name];
				[self message:[NSString stringWithFormat:@"%@%@", val == NSOffState ? @"no" : @"", defaults_name]];
			} else {
				NSString *val = [[NSUserDefaults standardUserDefaults] stringForKey:defaults_name];
				[self message:[NSString stringWithFormat:@"%@=%@", defaults_name, val]];
			}
			continue;
		}

		if ([booleans containsObject:defaults_name]) {
			if (equals != NSNotFound) {
				[self message:@"set: [no]%@ option doesn't take a value", defaults_name];
				return;
			}
			
			[[NSUserDefaults standardUserDefaults] setInteger:turnoff ? NSOffState : NSOnState forKey:defaults_name];
		} else {
			if (equals == NSNotFound) {
				NSString *val = [[NSUserDefaults standardUserDefaults] stringForKey:defaults_name];
				[self message:[NSString stringWithFormat:@"%@=%@", defaults_name, val]];
			} else {
				NSString *val = [var substringFromIndex:equals + 1];
				[[NSUserDefaults standardUserDefaults] setObject:val forKey:defaults_name];
			}
		}
	}
}

- (void)ex_split:(ExCommand *)command
{
	[windowController splitViewHorizontally:nil];
	// FIXME: open command.filename in new split view
}

- (void)ex_vsplit:(ExCommand *)command
{
	[windowController splitViewVertically:nil];
	// FIXME: open command.filename in new split view
}

@end

