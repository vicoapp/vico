#import "ExEnvironment.h"
#import "ExCommand.h"
#import "ViTheme.h"
#import "ViThemeStore.h"
#import "ViTextView.h"
#import "ViWindowController.h"
#import "ViDocumentView.h"
#import "ViTextStorage.h"
#import "ViCharsetDetector.h"
#import "ViDocumentController.h"
#import "ViBundleStore.h"
#import "NSString-scopeSelector.h"
#import "ViURLManager.h"
#import "ViTransformer.h"
#import "ViError.h"
#include "logging.h"

@interface ExEnvironment (private)
- (IBAction)finishedExCommand:(id)sender;
- (NSURL *)parseExFilename:(NSString *)filename;
@end

@implementation ExEnvironment

@synthesize baseURL;
@synthesize window;

- (id)init
{
	self = [super init];
	if (self) {
		[self setBaseURL:[NSURL fileURLWithPath:NSHomeDirectory()]];
	}
	return self;
}

- (void)awakeFromNib
{
	[statusbar setFont:[NSFont userFixedPitchFontOfSize:12.0]];
	[statusbar setDelegate:self];
}

#pragma mark -

- (void)setBaseURL:(NSURL *)url
{
	if (![[url absoluteString] hasSuffix:@"/"])
		url = [NSURL URLWithString:[[url lastPathComponent] stringByAppendingString:@"/"]
			     relativeToURL:url];

	baseURL = [url absoluteURL];
}

- (void)deferred:(id<ViDeferred>)deferred status:(NSString *)statusMessage
{
	[self message:@"%@", statusMessage];
}

- (void)checkBaseURL:(NSURL *)url onCompletion:(void (^)(NSURL *url, NSError *error))aBlock
{
//	if (error == nil && [[url lastPathComponent] isEqualToString:@""])
//		url = [NSURL URLWithString:[conn home] relativeToURL:url];

	id<ViDeferred> deferred = [[ViURLManager defaultManager] fileExistsAtURL:url onCompletion:^(NSURL *normalizedURL, BOOL isDirectory, NSError *error) {
		if (error)
			[self message:@"%@: %@", [url absoluteString], [error localizedDescription]];
		else if (normalizedURL == nil)
			[self message:@"%@: no such file or directory", [url absoluteString]];
		else if (!isDirectory)
			[self message:@"%@: not a directory", [normalizedURL absoluteString]];
		else {
			[self setBaseURL:normalizedURL];
			aBlock([self baseURL], error);
			return;
		}
		aBlock(nil, error);
	}];
	[deferred setDelegate:self];
}

- (NSString *)displayBaseURL
{
	if ([baseURL isFileURL])
		return [[baseURL path] stringByAbbreviatingWithTildeInPath];
	return [baseURL absoluteString];
}

- (void)message:(NSString *)fmt, ...
{
	va_list ap;
	va_start(ap, fmt);
	[windowController message:fmt arguments:ap];
	va_end(ap);
}

#pragma mark -
#pragma mark Input of ex commands

- (NSURL *)parseExFilename:(NSString *)filename
{
	NSError *error = nil;
	NSString *trimmed = [filename stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSURL *url = [[ViDocumentController sharedDocumentController] normalizePath:trimmed
									 relativeTo:self.baseURL
									      error:&error];
	if (error) {
		[self message:@"%@: %@",
		    trimmed, [error localizedDescription]];
		return nil;
	}

	return url;
}

- (void)cancel_ex_command
{
	exDelegate = nil;
	exTextView = nil;
	exContextInfo = NULL;

	[statusbar setStringValue:@""];
	[statusbar setEditable:NO];
	[statusbar setHidden:YES];
	[messageField setHidden:NO];
	[projectDelegate cancelExplorer];

	[[window windowController] focusEditor];
}

- (void)execute_ex_command:(NSString *)exCommand
{
	[exDelegate performSelector:exCommandSelector
			 withObject:exCommand
			 withObject:exContextInfo];

	[self cancel_ex_command];
}

- (void)getExCommandWithDelegate:(id)aDelegate
			selector:(SEL)aSelector
			  prompt:(NSString *)aPrompt
		     contextInfo:(void *)contextInfo
{
	[messageField setHidden:YES];
	[statusbar setHidden:NO];
	[statusbar setEditable:YES];
	exCommandSelector = aSelector;
	exDelegate = aDelegate;
	exContextInfo = contextInfo;
	[window makeFirstResponder:statusbar];
}

- (void)parseAndExecuteExCommand:(NSString *)exCommandString
		     contextInfo:(void *)contextInfo
{
	if ([exCommandString length] > 0) {
		NSError *error = nil;
		ExCommand *ex = [[ExCommand alloc] init];
		if ([ex parse:exCommandString error:&error]) {
			if (ex.command == nil)
				/* do nothing */ return;
			SEL selector = NSSelectorFromString([NSString stringWithFormat:@"%@:", ex.command->method]);
			if ([self respondsToSelector:selector])
				[self performSelector:selector withObject:ex];
			else
				[self message:@"The %@ command is not implemented.", ex.name];
		} else if (error)
			[self message:[error localizedDescription]];
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
	[self getExCommandWithDelegate:self
	                      selector:@selector(parseAndExecuteExCommand:contextInfo:)
	                        prompt:@":"
	                   contextInfo:NULL];
}

#pragma mark -
#pragma mark Ex commands


- (void)ex_write:(ExCommand *)command
{
	if (exTextView == nil)
		return;

	ViDocument *doc = [(ViDocumentView *)[windowController viewControllerForView:exTextView] document];
	DEBUG(@"got %i addresses", command.naddr);
	if ([command.string hasPrefix:@">>"]) {
		[self message:@"Appending not yet supported"];
		return;
	}

	if ([command.string length] == 0) {
		[doc saveDocument:self];
	} else {
		__block NSError *error = nil;
		NSURL *newURL = [[ViDocumentController sharedDocumentController]
		    normalizePath:command.string
		       relativeTo:[self baseURL]
			    error:&error];
		if (error != nil) {
			[NSApp presentError:error];
			return;
		}

		id<ViDeferred> deferred;
		ViURLManager *urlman = [ViURLManager defaultManager];
		__block NSDictionary *attributes = nil;
		__block NSURL *normalizedURL = nil;
		deferred = [urlman attributesOfItemAtURL:newURL
				      onCompletion:^(NSURL *_url, NSDictionary *_attrs, NSError *_err) {
			normalizedURL = _url;
			attributes = _attrs;
			if (![_err isFileNotFoundError])
				error = _err;
		}];
		[deferred wait];

		if (error) {
			[self message:@"%@", [error localizedDescription]];
			return;
		}

		if (normalizedURL && ![[attributes fileType] isEqualToString:NSFileTypeRegular]) {
			[self message:@"%@ is not a regular file", normalizedURL];
			return;
		}

		if (normalizedURL && (command.flags & E_C_FORCE) != E_C_FORCE) {
			[self message:@"File exists (add ! to override)"];
			return;
		}

		if ([doc saveToURL:newURL
			    ofType:nil
		  forSaveOperation:NSSaveAsOperation
			     error:&error] == NO)
			[self message:@"%@", [error localizedDescription]];
	}
}

/* syntax: bd[elete] bufname */
- (void)ex_bdelete:(ExCommand *)command
{
	if ((command.flags & E_C_FORCE) == E_C_FORCE)
		[[windowController currentDocument] close];
	else
		[windowController closeCurrentDocumentAndWindow:NO];
}

- (void)ex_quit:(ExCommand *)command
{
	if ((command.flags & E_C_FORCE) == E_C_FORCE)
		[[windowController currentDocument] closeAndWindow:YES];
	else
		[windowController closeCurrentDocumentAndWindow:YES];
	// FIXME: quit app if last window?
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
	NSString *path = command.filename ?: @"~";
	[self checkBaseURL:[self parseExFilename:path] onCompletion:^(NSURL *url, NSError *error) {
		if (url && !error) {
			[self ex_pwd:nil];
			[windowController.explorer browseURL:url andDisplay:NO];
		}
	}];
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
		NSURL *url = [self parseExFilename:command.filename];
		if (url) {
			NSError *error = nil;
			ViDocument *doc;
			doc = [[ViDocumentController sharedDocumentController]
				openDocumentWithContentsOfURL:url
						      display:YES
							error:&error];
			if (error) {
				[self message:@"%@: %@", url, [error localizedDescription]];
				return;
			}
		}
	}
}

- (void)ex_tabedit:(ExCommand *)command
{
	if (command.filename == nil)
		/* Re-open current file. Check E_C_FORCE in flags. */ ;
	else {
		NSURL *url = [self parseExFilename:command.filename];
		if (url) {
			NSError *error = nil;
			ViDocument *doc;
			doc = [[ViDocumentController sharedDocumentController]
				openDocumentWithContentsOfURL:url
						      display:NO
							error:&error];
			if (error) {
				[self message:@"%@: %@", url, [error localizedDescription]];
				return;
			} else if (doc)
				[windowController createTabForDocument:doc];
		}
	}
}

- (BOOL)ex_new:(ExCommand *)command
{
	return [windowController splitVertically:NO
					 andOpen:[self parseExFilename:command.filename]
			      orSwitchToDocument:nil] != nil;
	return NO;
}

- (BOOL)ex_tabnew:(ExCommand *)command
{
	NSError *error = nil;
	ViDocument *doc = [[ViDocumentController sharedDocumentController]
	    openUntitledDocumentAndDisplay:YES error:&error];
	doc.isTemporary = YES;
	if (error) {
		[self message:@"%@", [error localizedDescription]];
		return NO;
	}

	return YES;
}

- (BOOL)ex_vnew:(ExCommand *)command
{
	return [windowController splitVertically:YES
					 andOpen:[self parseExFilename:command.filename]
			      orSwitchToDocument:nil] != nil;
	return NO;
}

- (BOOL)ex_split:(ExCommand *)command
{
	return [windowController splitVertically:NO
					 andOpen:[self parseExFilename:command.filename]
			      orSwitchToDocument:[windowController currentDocument]] != nil;
	return NO;
}

- (BOOL)ex_vsplit:(ExCommand *)command
{
	return [windowController splitVertically:YES
					 andOpen:[self parseExFilename:command.filename]
			      orSwitchToDocument:[windowController currentDocument]] != nil;
	return NO;
}

- (BOOL)resolveExAddresses:(ExCommand *)command intoLineRange:(NSRange *)outRange
{
	NSUInteger begin_line, end_line;
	ViMark *m = nil;
	ViTextStorage *storage = (ViTextStorage *)[exTextView textStorage];

	switch (command.addr1->type) {
	case EX_ADDR_ABS:
		if (command.addr1->addr.abs.line == -1)
			begin_line = [storage lineCount];
		else
			begin_line = command.addr1->addr.abs.line;
		break;
	case EX_ADDR_RELATIVE:
	case EX_ADDR_CURRENT:
		begin_line = [exTextView currentLine];
		break;
	case EX_ADDR_MARK:
		m = [exTextView markNamed:command.addr1->addr.mark];
		if (m == nil) {
			[self message:@"Mark %C: not set", command.addr1->addr.mark];
			return NO;
		}
		begin_line = m.line;
		break;
	case EX_ADDR_NONE:
	default:
		return NO;
		break;
	}

	begin_line += command.addr1->offset;
	if ([storage locationForStartOfLine:begin_line] == -1ULL)
		return NO;

	switch (command.addr2->type) {
	case EX_ADDR_ABS:
		if (command.addr2->addr.abs.line == -1)
			end_line = [storage lineCount];
		else
			end_line = command.addr2->addr.abs.line;
		break;
	case EX_ADDR_CURRENT:
		end_line = [exTextView currentLine];
		break;
	case EX_ADDR_MARK:
		m = [exTextView markNamed:command.addr2->addr.mark];
		if (m == nil) {
			[self message:@"Mark %C: not set", command.addr2->addr.mark];
			return NO;
		}
		end_line = m.line;
		break;
	case EX_ADDR_RELATIVE:
	case EX_ADDR_NONE:
		end_line = begin_line;
		break;
	default:
		return NO;
	}

	end_line += command.addr2->offset;
	if ([storage locationForStartOfLine:end_line] == -1ULL)
		return NO;

	*outRange = NSMakeRange(begin_line, end_line - begin_line);
	return YES;
}

- (BOOL)resolveExAddresses:(ExCommand *)command intoRange:(NSRange *)outRange
{
	NSRange lineRange;
	if ([self resolveExAddresses:command intoLineRange:&lineRange] == NO)
		return NO;

	ViTextStorage *storage = (ViTextStorage *)[exTextView textStorage];
	NSUInteger beg = [storage locationForStartOfLine:lineRange.location];
	NSUInteger end = [storage locationForStartOfLine:NSMaxRange(lineRange)];

	/* end location should include the contents of the end_line */
	[exTextView getLineStart:NULL end:&end contentsEnd:NULL forLocation:end];
	*outRange = NSMakeRange(beg, end - beg);
	return YES;
}

- (void)filterFinishedWithStatus:(int)status standardOutput:(NSString *)outputText contextInfo:(id)contextInfo
{
	if (status != 0)
		[self message:@"%@: exited with status %i", filterCommand, status];
	else {
		NSRange range = [(NSValue *)contextInfo rangeValue];
		DEBUG(@"replace range %@ with %zu characters", NSStringFromRange(range), [outputText length]);
		[exTextView replaceRange:range withString:outputText];
		[exTextView endUndoGroup];
	}
}

- (void)filterFinish
{
	DEBUG(@"wait until exit of command %@", filterCommand);
	[filterTask waitUntilExit];
	int status = [filterTask terminationStatus];
	DEBUG(@"status = %d", status);
 
	if (filterFailed)
		status = -1;
 
	/* Try to auto-detect the encoding. */
	NSStringEncoding encoding = [[ViCharsetDetector defaultDetector] encodingForData:filterOutput];
	if (encoding == 0)
		/* Try UTF-8 if auto-detecting fails. */
		encoding = NSUTF8StringEncoding;
	NSString *outputText = [[NSString alloc] initWithData:filterOutput encoding:encoding];
	if (outputText == nil) {
		/* If all else fails, use iso-8859-1. */
		encoding = NSISOLatin1StringEncoding;
		outputText = [[NSString alloc] initWithData:filterOutput encoding:encoding];
	}

	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[filterTarget methodSignatureForSelector:filterSelector]];
	[invocation setSelector:filterSelector];
	[invocation setArgument:&status atIndex:2];
	[invocation setArgument:&outputText atIndex:3];
	[invocation setArgument:&filterContextInfo atIndex:4];
	[invocation invokeWithTarget:filterTarget];

	filterTask = nil;
	filterCommand = nil;
	filterOutput = nil;
	filterTarget = nil;
	filterContextInfo = nil;
}

- (void)filterSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];

	if (returnCode == -1) {
		DEBUG(@"terminating filter task %@", filterTask);
		[filterTask terminate];
	}
	
	[filterIndicator stopAnimation:self];
	[self filterFinish];
}

- (IBAction)filterCancel:(id)sender
{
	[NSApp endSheet:filterSheet returnCode:-1];
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)event
{
	DEBUG(@"got event %lu on stream %@", event, stream);

	const void *ptr;
	NSUInteger len;

	switch (event) {
	case NSStreamEventNone:
	case NSStreamEventOpenCompleted:
	default:
		break;
	case NSStreamEventHasBytesAvailable:
		[filterStream getBuffer:&ptr length:&len];
		DEBUG(@"got %lu bytes", len);
		if (len > 0) {
			[filterOutput appendBytes:ptr length:len];
		}
		break;
	case NSStreamEventHasSpaceAvailable:
		/* All output data flushed. */
		[filterStream shutdownWrite];
		break;
	case NSStreamEventErrorOccurred:
		INFO(@"error on stream %@: %@", stream, [stream streamError]);
		filterFailed = 1;
		break;
	case NSStreamEventEndEncountered:
		DEBUG(@"EOF on stream %@", stream);
		if ([window attachedSheet] != nil)
			[NSApp endSheet:filterSheet returnCode:0];
		filterDone = YES;
		break;
	}
}

- (void)filterText:(NSString *)inputText
       throughTask:(NSTask *)task
            target:(id)target
          selector:(SEL)selector
       contextInfo:(id)contextInfo
      displayTitle:(NSString *)displayTitle
{
	filterTask = task;

	NSPipe *shellInput = [NSPipe pipe];
	NSPipe *shellOutput = [NSPipe pipe];

	[filterTask setStandardInput:shellInput];
	[filterTask setStandardOutput:shellOutput];
	//[filterTask setStandardError:shellOutput];

	[filterTask launch];

	// setup a new runloop mode
	// schedule read and write in this mode
	// schedule a timer to track how long the task takes to complete
	// if not finished within x seconds, show a modal sheet, re-adding the runloop sources to the modal sheet runloop(?)
	// accept cancel button from sheet -> terminate task and cancel filter

	NSString *mode = NSDefaultRunLoopMode; //ViFilterRunLoopMode;

	filterStream = [[ViBufferedStream alloc] initWithTask:filterTask];
	[filterStream setDelegate:self];

	filterOutput = [NSMutableData dataWithCapacity:[inputText length]];
	[filterStream writeData:[inputText dataUsingEncoding:NSUTF8StringEncoding]];

	filterDone = NO;
	filterFailed = NO;

	filterTarget = target;
	filterSelector = selector;
	filterContextInfo = contextInfo;


	/* schedule the read and write sources in the new runloop mode */
	[filterStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:mode];

	NSDate *limitDate = [NSDate dateWithTimeIntervalSinceNow:2.0];

	int done = 0;

	for (;;) {
		[[NSRunLoop currentRunLoop] runMode:mode beforeDate:limitDate];
		if ([limitDate timeIntervalSinceNow] <= 0) {
			DEBUG(@"limit date %@ reached", limitDate);
			break;
		}

		if (filterFailed) {
			DEBUG(@"%s", "filter I/O failed");
			[filterTask terminate];
			done = -1;
			break;
		}

		if (filterDone) {
			done = 1;
			break;
		}
	}

	if (done) {
		[self filterFinish];
	} else {
		[NSApp beginSheet:filterSheet
                   modalForWindow:window
                    modalDelegate:self
                   didEndSelector:@selector(filterSheetDidEnd:returnCode:contextInfo:)
                      contextInfo:NULL];
		[filterLabel setStringValue:displayTitle];
		[filterLabel setFont:[NSFont userFixedPitchFontOfSize:12.0]];
		[filterIndicator startAnimation:self];
		[filterStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:mode];
	}
}

- (void)filterText:(NSString *)inputText
    throughCommand:(NSString *)shellCommand
            target:(id)target
          selector:(SEL)selector
       contextInfo:(id)contextInfo
{
	if ([shellCommand length] == 0)
		return;

	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:@"/bin/bash"];
	[task setArguments:[NSArray arrayWithObjects:@"-c", shellCommand, nil]];

	filterCommand = shellCommand;

	return [self filterText:inputText
		    throughTask:task
			 target:target
		       selector:selector
		    contextInfo:contextInfo
		   displayTitle:shellCommand];
}

- (void)ex_bang:(ExCommand *)command
{
	if (![exTextView isKindOfClass:[ViTextView class]]) {
		[self message:@"not implemented"];
		return;
	}

	NSRange range;
	if (![self resolveExAddresses:command intoRange:&range])
		return;
	if (range.location == NSNotFound)
		[self message:@"not implemented"];
	else {
		ViTextStorage *storage = (ViTextStorage *)[exTextView textStorage];
		NSString *inputText = [[storage string] substringWithRange:range];
		[self filterText:inputText
                  throughCommand:command.string
                          target:self
                        selector:@selector(filterFinishedWithStatus:standardOutput:contextInfo:)
                     contextInfo:[NSValue valueWithRange:range]];
	}
}

- (void)ex_number:(ExCommand *)command
{
	NSRange range;
	if (![self resolveExAddresses:command intoRange:&range]) {
		[self message:@"Movement past the end-of-file"];
		return;
	}

	NSUInteger location = [[exTextView textStorage] firstNonBlankForLineAtLocation:range.location];
	[exTextView setCaret:location];
	[exTextView scrollRangeToVisible:NSMakeRange(location, 0)];
}

- (void)ex_set:(ExCommand *)command
{
	NSDictionary *variables = [NSDictionary dictionaryWithObjectsAndKeys:
		@"shiftwidth", @"sw",
		@"autoindent", @"ai",
		@"smartindent", @"si",
		@"expandtab", @"et",
		@"smartpair", @"smp",
		@"tabstop", @"ts",
		@"wrap", @"wrap",
		@"smarttab", @"sta",

		@"showguide", @"sg",
		@"guidecolumn", @"gc",
		@"prefertabs", @"prefertabs",
		@"ignorecase", @"ic",
		@"smartcase", @"scs",
		@"number", @"nu",
		@"number", @"num",
		@"number", @"numb",
		@"autocollapse", @"ac",  // automatically collapses other documents in the symbol list
		@"hidetab", @"ht",  // hide tab bar for single tabs
		@"fontsize", @"fs",
		@"fontname", @"font",
		@"searchincr", @"searchincr",
		@"antialias", @"antialias",
		@"undostyle", @"undostyle",
		@"list", @"list",
		@"formatprg", @"fp",
		@"cursorline", @"cul",
		nil];

	NSArray *booleans = [NSArray arrayWithObjects:
	    @"autoindent", @"expandtab", @"smartpair", @"ignorecase", @"smartcase", @"number",
	    @"autocollapse", @"hidetab", @"showguide", @"searchincr", @"smartindent",
	    @"wrap", @"antialias", @"list", @"smarttab", @"prefertabs", @"cursorline", nil];
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
				NSInteger val = [[NSUserDefaults standardUserDefaults] integerForKey:defaults_name];
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

- (BOOL)ex_export:(ExCommand *)command
{
	if (command.string == nil)
		return NO;

	NSScanner *scan = [NSScanner scannerWithString:command.string];
	NSString *variable, *value = nil;

	if (![scan scanUpToString:@"=" intoString:&variable] ||
	    ![scan scanString:@"=" intoString:nil]) {
		return NO;
	}

	if (![scan isAtEnd])
		value = [[scan string] substringFromIndex:[scan scanLocation]];

	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSDictionary *curenv = [defs dictionaryForKey:@"environment"];
	NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:curenv];

	if (value)
		[env setObject:value forKey:variable];
	else
		[env removeObjectForKey:value];

	[defs setObject:env forKey:@"environment"];

	DEBUG(@"static environment is now %@", env);

	return YES;
}

- (BOOL)ex_buffer:(ExCommand *)command
{
	if ([command.string length] == 0)
		return NO;

	NSMutableArray *matches = [NSMutableArray array];

	ViDocument *doc = nil;
	for (doc in [windowController documents]) {
		if ([doc fileURL] &&
		    [[[doc fileURL] absoluteString] rangeOfString:command.string
							  options:NSCaseInsensitiveSearch].location != NSNotFound)
			[matches addObject:doc];
	}

	if ([matches count] == 0) {
		[self message:@"No matching buffer for %@", command.string];
		return NO;
	} else if ([matches count] > 1) {
		[self message:@"More than one match for %@", command.string];
		return NO;
	}

	doc = [matches objectAtIndex:0];
	if ([command.command->name hasPrefix:@"b"]) {
		if ([windowController currentDocument] != doc)
			[windowController switchToDocument:doc];
	} else if ([command.command->name isEqualToString:@"tbuffer"]) {
		ViDocumentView *docView = [windowController viewForDocument:doc];
		if (docView == nil)
			[windowController createTabForDocument:doc];
		else
			[windowController selectDocumentView:docView];
	} else
		/* otherwise it's either sbuffer or vbuffer */
		[windowController splitVertically:[command.command->name isEqualToString:@"vbuffer"]
					  andOpen:nil
			       orSwitchToDocument:doc
				  allowReusedView:YES];

	return YES;
}

- (BOOL)ex_setfiletype:(ExCommand *)command
{
	if ([command.words count] != 1)
		return NO;

	id<ViViewController> viewController = [windowController currentView];
	if (viewController == nil || ![viewController isKindOfClass:[ViDocumentView class]])
		return NO;

	NSString *langScope = [command.words objectAtIndex:0];
	NSString *pattern = [NSString stringWithFormat:@"(^|\\.)%@(\\.|$)", [ViRegexp escape:langScope]];
	ViRegexp *rx = [[ViRegexp alloc] initWithString:pattern];
	NSMutableSet *matches = [NSMutableSet set];
	ViLanguage *lang;
	for (lang in [[ViBundleStore defaultStore] languages]) {
		if ([[lang name] isEqualToString:langScope]) {
			/* full match */
			[matches removeAllObjects];
			[matches addObject:lang];
			break;
		} else if ([rx matchesString:[lang name]]) {
			/* partial match */
			[matches addObject:lang];
		}
	}

	if ([matches count] == 0) {
		[self message:@"Unknown syntax %@", langScope];
		return NO;
	} else if ([matches count] > 1) {
		[self message:@"More than one match for %@", langScope];
		DEBUG(@"matches: %@", matches);
		return NO;
	}

	ViDocumentView *docView = viewController;
	[[docView document] setLanguage:[matches anyObject]];
	return YES;
}

- (BOOL)ex_s:(ExCommand *)command
{
	NSRange exRange;
	if (![self resolveExAddresses:command intoLineRange:&exRange]) {
		[self message:@"Invalid addresses"];
		return NO;
	}

	unsigned rx_options = ONIG_OPTION_NOTBOL | ONIG_OPTION_NOTEOL;
	if ([command.string rangeOfString:@"i"].location != NSNotFound)
		rx_options |= ONIG_OPTION_IGNORECASE;

	ViRegexp *rx = nil;

	/* compile the pattern regexp */
	@try {
		rx = [[ViRegexp alloc] initWithString:command.pattern
					      options:rx_options];
	}
	@catch(NSException *exception) {
		[self message:@"Invalid search pattern: %@", exception];
		return NO;
	}

	ViTextStorage *storage = [exTextView textStorage];
	ViTransformer *tform = [[ViTransformer alloc] init];
	NSError *error = nil;

	NSString *s = [storage string];
	DEBUG(@"ex range is %@", NSStringFromRange(exRange));

	for (NSUInteger lineno = exRange.location; lineno <= NSMaxRange(exRange); lineno++) {
		NSUInteger bol = [storage locationForStartOfLine:lineno];
		NSUInteger end, eol;
		[s getLineStart:NULL end:&end contentsEnd:&eol forRange:NSMakeRange(bol, 0)];

		NSRange lineRange = NSMakeRange(bol, eol - bol);
		NSString *value = [s substringWithRange:lineRange];
		DEBUG(@"range %@ = %@", NSStringFromRange(lineRange), value);
		NSString *replacedText = [tform transformValue:value
						   withPattern:rx
							format:command.replacement
						       options:command.string
							 error:&error];
		if (error) {
			[self message:@"substitute failed: %@", [error localizedDescription]];
			return NO;
		}

		if (replacedText != value)
			[exTextView replaceCharactersInRange:lineRange withString:replacedText];
	}

	[exTextView endUndoGroup];
	NSUInteger final_location = [storage locationForStartOfLine:NSMaxRange(exRange)];
	[exTextView setCaret:final_location];
	[exTextView scrollToCaret];

	return YES;
}

@end

