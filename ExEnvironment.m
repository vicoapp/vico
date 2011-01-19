#import "ExEnvironment.h"
#import "ExCommand.h"
#import "ViTheme.h"
#import "ViThemeStore.h"
#import "ViTextView.h"
#import "ViWindowController.h"
#import "ViDocumentView.h"
#import "NSTextStorage-additions.h"
#import "SFTPConnectionPool.h"
#include "logging.h"

@interface ExEnvironment (private)
- (NSString *)filenameAtLocation:(NSUInteger)aLocation inFieldEditor:(NSText *)fieldEditor range:(NSRange *)outRange;
- (unsigned)completePath:(NSString *)partialPath relativeToURL:(NSURL *)url into:(NSString **)longestMatchPtr matchesIntoArray:(NSArray **)matchesPtr;
- (void)displayCompletions:(NSArray *)completions forURL:(NSURL *)url;
- (NSURL *)parseExFilename:(NSString *)filename;
@end

@implementation ExEnvironment

@synthesize baseURL;

- (id)init
{
	self = [super init];
	if (self) {
		exCommandHistory = [[NSMutableArray alloc] init];
                [self setBaseURL:[NSURL fileURLWithPath:[[NSFileManager defaultManager] currentDirectoryPath]]];
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

#pragma mark -
#pragma mark Assorted

- (BOOL)setBaseURL:(NSURL *)url
{
	if ([url isFileURL]) {
		BOOL isDirectory = NO;
		if (![[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDirectory] || !isDirectory) {
			[self message:@"%@: not a directory", [url path]];
			return NO;
		}
	}

	if ([[url scheme] isEqualToString:@"sftp"]) {
		NSError *error = nil;
		SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:url error:&error];

		if (error == nil && [[url lastPathComponent] isEqualToString:@""])
			url = [NSURL URLWithString:[conn home] relativeToURL:url];

		BOOL isDirectory = NO;
		BOOL exists = [conn fileExistsAtPath:[url path] isDirectory:&isDirectory error:&error];
		if (error) {
			[self message:@"%@: %@", [url absoluteString], [error localizedDescription]];
			return NO;
		}
		if (!exists) {
			[self message:@"%@: no such file or directory", [url absoluteString]];
			return NO;
		}
		if (!isDirectory) {
			[self message:@"%@: not a directory", [url absoluteString]];
			return NO;
		}
	}

	if (![[url absoluteString] hasSuffix:@"/"])
		url = [NSURL URLWithString:[[url lastPathComponent] stringByAppendingString:@"/"] relativeToURL:url];

	baseURL = [url absoluteURL];
	return YES;
}

- (NSString *)displayBaseURL
{
	if ([baseURL isFileURL])
		return [[baseURL path] stringByAbbreviatingWithTildeInPath];
	return [baseURL absoluteString];
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

#if 0
// tag push
- (void)pushLine:(NSUInteger)aLine column:(NSUInteger)aColumn
{
	[[windowController sharedTagStack] pushFile:[[self fileURL] path] line:aLine column:aColumn];
}

- (void)popTag
{
	NSDictionary *location = [[windowController sharedTagStack] pop];
	if (location == nil) {
		[self message:@"The tags stack is empty"];
		return;
	}

	[windowController gotoURL:[NSURL fileURLWithPath:[location objectForKey:@"file"]]
			     line:[[location objectForKey:@"line"] unsignedIntegerValue]
			   column:[[location objectForKey:@"column"] unsignedIntegerValue]];
}
#endif

- (void)switchToLastDocument
{
	[windowController switchToLastDocument];
}

- (void)selectLastDocument
{
	[windowController selectLastDocument];
}

- (void)selectTabAtIndex:(NSInteger)anIndex
{
	[windowController selectTabAtIndex:anIndex];
}


- (BOOL)selectViewAtPosition:(ViViewOrderingMode)position relativeTo:(ViTextView *)aTextView
{
	ViDocumentView *docView = [windowController documentViewForView:aTextView];
	ViDocumentView *otherView = [[docView tabController] viewAtPosition:position relativeTo:[docView view]];
	if (otherView == nil)
		return NO;
	[windowController selectDocumentView:otherView];
	return YES;
}

#pragma mark -
#pragma mark Filename completion

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

- (unsigned)completePath:(NSString *)partialPath relativeToURL:(NSURL *)url into:(NSString **)longestMatchPtr matchesIntoArray:(NSArray **)matchesPtr
{
	NSString *path;
	NSString *suffix;
	if ([partialPath hasSuffix:@"/"]) {
		path = partialPath;
		suffix = @"";
	} else {
		path = [partialPath stringByDeletingLastPathComponent];
		suffix = [partialPath lastPathComponent];
	}

	int options = 0;
	if ([url isFileURL])
		/* FIXME: check if local filesystem is case sensitive? */
		options |= NSCaseInsensitiveSearch;

	SFTPConnection *conn = nil;
	NSFileManager *fm = nil;

	NSArray *directoryContents;
	NSError *error = nil;
	if ([url isFileURL]) {
		fm = [NSFileManager defaultManager];
		directoryContents = [fm contentsOfDirectoryAtPath:path error:&error];
	} else {
		conn = [[SFTPConnectionPool sharedPool] connectionWithURL:url error:&error];
		directoryContents = [conn contentsOfDirectoryAtPath:path error:&error];
	}

	if (error) {
		[self message:@"%@: %@", [NSURL URLWithString:partialPath relativeToURL:url], [error localizedDescription]];
		return 0;
	}

	NSMutableArray *matches = [[NSMutableArray alloc] init];
	id entry;
	for (entry in directoryContents) {
		NSString *filename;
		if ([url isFileURL])
			filename = entry;
		else
			filename = [[(SFTPDirectoryEntry *)entry filename] lastPathComponent];

		NSRange r = NSIntersectionRange(NSMakeRange(0, [suffix length]), NSMakeRange(0, [filename length]));
		if ([filename compare:suffix options:options range:r] == NSOrderedSame) {
			/* Only show dot-files if explicitly requested. */
			if ([filename hasPrefix:@"."] && ![suffix hasPrefix:@"."])
				continue;

			NSString *s = [path stringByAppendingPathComponent:filename];
			BOOL isDirectory = NO;

			if ([url isFileURL])
				[fm fileExistsAtPath:s isDirectory:&isDirectory];
			else
				isDirectory = [entry isDirectory];
			if (isDirectory)
				s = [s stringByAppendingString:@"/"];
			[matches addObject:s];
		}
	}

	if (longestMatchPtr && [matches count] > 0) {
		NSString *longestMatch = nil;
		NSString *firstMatch = [matches objectAtIndex:0];
		for (NSString *m in matches) {
			NSString *commonPrefix = [firstMatch commonPrefixWithString:m options:options];
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
	for (c in completions) {
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
		[style removeTabStop:tabStop];
	[style setDefaultTabInterval:colsize];

	[[[commandOutput textStorage] mutableString] setString:@""];
	int n = 0;
	for (c in completions)
		[[[commandOutput textStorage] mutableString] appendFormat:@"%@%@",
			[c substringFromIndex:skipIndex], (++n % columns) == 0 ? @"\n" : @"\t"];

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

#pragma mark -
#pragma mark Input of ex commands

/*
 * Returns YES if the key binding was handled.
 */
- (BOOL)control:(NSControl *)sender textView:(NSTextView *)textView doCommandBySelector:(SEL)aSelector
{
	if (sender == statusbar)
	{
		if (aSelector == @selector(cancelOperation:) || // escape
		    aSelector == @selector(noop:) ||            // ctrl-c and ctrl-g ...
		    aSelector == @selector(insertNewline:) ||
		    (aSelector == @selector(deleteBackward:) && [textView selectedRange].location == 0))
		{
			[commandSplit setPosition:NSHeight([commandSplit frame]) ofDividerAtIndex:0];
			if (aSelector != @selector(insertNewline:))
				[statusbar setStringValue:@""];
			[[statusbar target] performSelector:[statusbar action] withObject:self afterDelay:0.0];
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
			NSUInteger caret = [textView selectedRange].location;
			NSRange range;
			NSString *filename = [self filenameAtLocation:caret inFieldEditor:textView range:&range];

			NSURL *url = [self parseExFilename:filename];

			filename = [url path];
			/* Put back the trailing slash. */
			if ([[url absoluteString] hasSuffix:@"/"])
				filename = [filename stringByAppendingString:@"/"];

			NSArray *completions = nil;
			NSString *completion = nil;
			NSUInteger num = [self completePath:filename relativeToURL:url into:&completion matchesIntoArray:&completions];

			if (completion) {
				NSMutableString *s = [[NSMutableString alloc] initWithString:[textView string]];
				if ([url isFileURL])
					[s replaceCharactersInRange:range withString:completion];
				else
					[s replaceCharactersInRange:range withString:[[NSURL URLWithString:completion relativeToURL:url] absoluteString]];
				[textView setString:s];
			}

			if (num == 1 && [completion hasSuffix:@"/"]) {
				/* If only one directory match, show completions inside that directory. */
				num = [self completePath:completion relativeToURL:url into:&completion matchesIntoArray:&completions];
			}

			if (num > 1)
				[self displayCompletions:completions forPath:completion];

			return YES;
		}
	}
	return NO;
}

- (NSURL *)parseExFilename:(NSString *)filename
{
	NSURL *url;

	url = [NSURL URLWithString:filename];
	if (url == nil || [url scheme] == nil) {
		NSString *path = filename;
		if ([path hasPrefix:@"~"]) {
			if ([[self baseURL] isFileURL])
				path = [path stringByExpandingTildeInPath];
			else {
				NSError *error = nil;
				SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:[self baseURL] error:&error];
				if (error) {
					[self message:@"%@: %@", [self baseURL], [error localizedDescription]];
					return nil;
				}
				path = [path stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[conn home]];
			}
		}
		url = [NSURL URLWithString:path relativeToURL:[self baseURL]];
	}

	return url;
}

- (IBAction)finishedExCommand:(id)sender
{
	[statusbar setTarget:nil];
	[statusbar setAction:NULL];

	NSString *exCommand = [statusbar stringValue];

	if ([exCommand length] > 0) {
		[exDelegate performSelector:exCommandSelector withObject:exCommand withObject:exContextInfo];

		/* Add the command to the history. */
		NSUInteger i = [exCommandHistory indexOfObject:exCommand];
		if (i != NSNotFound)
			[exCommandHistory removeObjectAtIndex:i];
		[exCommandHistory addObject:exCommand];
	}

	exDelegate = nil;
	exTextView = nil;
	exContextInfo = NULL;

	[statusbar setStringValue:@""];
	[statusbar setEditable:NO];
	[statusbar setHidden:YES];
	[messageField setHidden:NO];

	[[window windowController] focusEditor];
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

- (void)executeForTextView:(ViTextView *)aTextView
{
	/*
	 * This global is a bit ugly. An alternative is to query
	 * the windowController directly for the current document
	 * and/or view. However, that might not play well with
	 * automating ex commands across multiple documents.
	 */
	exTextView = aTextView;
	[self getExCommandWithDelegate:self selector:@selector(parseAndExecuteExCommand:contextInfo:) prompt:@":" contextInfo:NULL];
}

#pragma mark -
#pragma mark Finding

#if 0
- (BOOL)findPattern:(NSString *)pattern options:(unsigned)find_options
{
	return [(ViTextView *)[[views objectAtIndex:0] textView] findPattern:pattern options:find_options];
}
#endif

#pragma mark -
#pragma mark Ex commands


- (void)ex_write:(ExCommand *)command
{
	ViDocument *doc = [[windowController documentViewForView:exTextView] document];
	[doc saveDocument:self];
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
#if 0
	NSString *path = command.filename;
	if (path == nil)
		path = [@"~" stringByExpandingTildeInPath];
	if (![path hasSuffix:@"/"])
		path = [path stringByAppendingString:@"/"];	/* Force directory URL. */
#endif

	NSString *path = command.filename ?: @"~";
	if (![self setBaseURL:[self parseExFilename:path]])
		[self message:@"%@: Failed to change directory.", path];
        else
        	[self ex_pwd:nil];
}

- (void)ex_pwd:(ExCommand *)command
{
	[self message:@"%@", [self displayBaseURL]];
}

- (void)ex_edit:(ExCommand *)command
{
	if (command.filename == nil)
		/* Re-open current file. Check E_C_FORCE in flags. */ ;
	else {
		NSError *error = nil;
		NSURL *url = [self parseExFilename:command.filename];
		BOOL isDirectory = NO;
		BOOL exists = NO;
		if ([url isFileURL])
			exists = [[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDirectory];
		else {
			SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:url error:&error];
			exists = [conn fileExistsAtPath:[url path] isDirectory:&isDirectory error:&error];
			if (error) {
				[self message:@"%@: %@", [url absoluteString], [error localizedDescription]];
				return;
			}
		}

		if (exists) {
			ViDocument *document;
			document = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url
													  display:YES
													    error:&error];
			if (document)
				[windowController selectDocument:document];
		} else {
			id doc = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:&error];
			[doc setFileURL:url];
		}

		if (error)
			[self message:@"%@: %@", [url absoluteString], [error localizedDescription]];
	}
}

- (BOOL)splitVertically:(BOOL)isVertical andOpen:(NSString *)filename orSwitchToDocument:(ViDocument *)doc
{
	NSError *err = nil;

	if (filename) {
		NSURL *url = [self parseExFilename:filename];
		doc = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url
											     display:NO
											       error:&err];
		if (err)
			[self message:@"%@: %@", [url absoluteString], [err localizedDescription]];
	} else if (doc == nil) {
		doc = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:NO error:&err];
		if (err)
			[self message:@"%@", [err localizedDescription]];
	}

	if (doc) {
		[doc addWindowController:windowController];
		[windowController addDocument:doc];
		if (isVertical)
			[windowController splitViewVertically:nil];
		else
			[windowController splitViewHorizontally:nil];
		[windowController switchToDocument:doc];
		return YES;
	}

	return NO;
}

- (BOOL)ex_new:(ExCommand *)command
{
	return [self splitVertically:NO andOpen:command.filename orSwitchToDocument:nil];
}

- (BOOL)ex_vnew:(ExCommand *)command
{
	return [self splitVertically:YES andOpen:command.filename orSwitchToDocument:nil];
}

- (BOOL)ex_split:(ExCommand *)command
{
	return [self splitVertically:NO andOpen:command.filename orSwitchToDocument:[windowController currentDocument]];
}

- (BOOL)ex_vsplit:(ExCommand *)command
{
	return [self splitVertically:YES andOpen:command.filename orSwitchToDocument:[windowController currentDocument]];
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

	NSInteger location = [[exTextView textStorage] locationForStartOfLine:line];
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

- (BOOL)ex_close:(ExCommand *)command
{
	BOOL didClose = [windowController closeCurrentViewUnlessLast];
	if (!didClose)
		[self message:@"Cannot close last window"];
	return didClose;
}

@end

