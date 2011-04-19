#import "ExEnvironment.h"
#import "ExCommand.h"
#import "ViTheme.h"
#import "ViThemeStore.h"
#import "ViTextView.h"
#import "ViWindowController.h"
#import "ViDocumentView.h"
#import "ViTextStorage.h"
#import "SFTPConnectionPool.h"
#import "ViCharsetDetector.h"
#import "ViDocumentController.h"
#import "ViBundleStore.h"
#import "NSString-scopeSelector.h"
#include "logging.h"

@interface ExEnvironment (private)
- (IBAction)finishedExCommand:(id)sender;
- (NSURL *)parseExFilename:(NSString *)filename;
@end

@implementation ExEnvironment

@synthesize baseURL;
@synthesize filterOutput;
@synthesize filterInput;
@synthesize window;
@synthesize filterSheet;
@synthesize filterLeft;
@synthesize filterPtr;
@synthesize filterDone;
@synthesize filterReadFailed;
@synthesize filterWriteFailed;

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
#pragma mark Assorted

- (BOOL)setBaseURL:(NSURL *)url
{
	if ([url isFileURL]) {
		BOOL isDirectory = NO;
		if (![[NSFileManager defaultManager] fileExistsAtPath:[url path]
							  isDirectory:&isDirectory] || !isDirectory) {
			[self message:@"%@: not a directory", [url path]];
			return NO;
		}
	}

	if ([[url scheme] isEqualToString:@"sftp"]) {
		NSError *error = nil;
		SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:url
										    error:&error];

		if (error == nil && [[url lastPathComponent] isEqualToString:@""])
			url = [NSURL URLWithString:[conn home] relativeToURL:url];

		BOOL isDirectory = NO;
		BOOL exists = [conn fileExistsAtPath:[url path]
					 isDirectory:&isDirectory
					       error:&error];
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
		url = [NSURL URLWithString:[[url lastPathComponent] stringByAppendingString:@"/"]
			     relativeToURL:url];

	baseURL = [url absoluteURL];
	return YES;
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
	if (exTextView) {
		ViDocument *doc = [(ViDocumentView *)[windowController viewControllerForView:exTextView] document];
		[doc saveDocument:self];
	}
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
	NSString *path = command.filename ?: @"~";
	if (![self setBaseURL:[self parseExFilename:path]])
		[self message:@"%@: Failed to change directory.", path];
        else {
        	[self ex_pwd:nil];
        	[windowController.explorer browseURL:[self baseURL] andDisplay:NO];
	}
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
		if (url)
			[[ViDocumentController sharedDocumentController] openDocument:url
									   andDisplay:YES
								       allowDirectory:YES];
	}
}

- (BOOL)ex_new:(ExCommand *)command
{
	return [windowController splitVertically:NO
					 andOpen:[self parseExFilename:command.filename]
			      orSwitchToDocument:nil] != nil;
	return NO;
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

- (BOOL)resolveExAddresses:(ExCommand *)command intoRange:(NSRange *)outRange
{
	NSUInteger begin, end;
	ViTextStorage *storage = (ViTextStorage *)[exTextView textStorage];

	switch (command.addr1->type) {
	case EX_ADDR_ABS:
		if (command.addr1->addr.abs.line == -1)
			begin = [[storage string] length];
		else
			begin = [storage locationForStartOfLine:command.addr1->addr.abs.line];
		break;
	case EX_ADDR_RELATIVE:
	case EX_ADDR_CURRENT:
		begin = [exTextView caret];
		break;
	case EX_ADDR_NONE:
	default:
		return NO;
		break;
	}

	begin += /* command.addr1->offset many _lines_ */ 0;

	switch (command.addr2->type) {
	case EX_ADDR_ABS:
		if (command.addr2->addr.abs.line == -1)
			end = [[storage string] length];
		else
			end = [storage locationForStartOfLine:command.addr2->addr.abs.line];
		break;
	case EX_ADDR_CURRENT:
		end = [exTextView caret];
		break;
	case EX_ADDR_RELATIVE:
	case EX_ADDR_NONE:
		end = begin;
		break;
	default:
		return NO;
	}

	end += /* command.addr2->offset many _lines_ */ 0;

	*outRange = NSMakeRange(begin, end - begin);
	return YES;
}

static void
filter_read(CFSocketRef s,
	     CFSocketCallBackType callbackType,
	     CFDataRef address,
	     const void *data,
	     void *info)
{
	char buf[64*1024];
	ExEnvironment *env = info;
	ssize_t ret;
	int fd = CFSocketGetNative(s);

	ret = read(fd, buf, sizeof(buf));
	if (ret <= 0) {
		if (ret == 0) {
			DEBUG(@"read EOF from fd %d", fd);
			if ([env.window attachedSheet] != nil)
				[NSApp endSheet:env.filterSheet returnCode:0];
			env.filterDone = YES;
		} else {
			INFO(@"read(%d) failed: %s", fd, strerror(errno));
			env.filterReadFailed = 1;
		}
		// XXX: Do not in either case close the underlying native socket without invalidating the CFSocket object.
		CFSocketInvalidate(s);
	} else {
		DEBUG(@"read %zi bytes from fd %i", ret, fd);
		[env.filterOutput appendBytes:buf length:ret];
	}
}

static void
filter_write(CFSocketRef s,
	     CFSocketCallBackType callbackType,
	     CFDataRef address,
	     const void *data,
	     void *info)
{
	ExEnvironment *env = info;
	size_t len = 64*1024;
	int fd = CFSocketGetNative(s);

	if (len > env.filterLeft)
		len = env.filterLeft;

	if (len > 0) {
		ssize_t ret = write(fd, env.filterPtr, len);
		if (ret <= 0) {
			if (errno == EAGAIN || errno == EINTR) {
				CFSocketEnableCallBacks(s, kCFSocketWriteCallBack);
				return;
			}

			INFO(@"write(%zu) failed: %s", len, strerror(errno));
			CFSocketInvalidate(s);
			env.filterWriteFailed = 1;
			return;
		}

		env.filterPtr = env.filterPtr + ret;
		// ctx->ptr += ret;
		// ctx->left -= ret;
		env.filterLeft = env.filterLeft - ret;

		DEBUG(@"wrote %zi bytes, %zu left", ret, env.filterLeft);
	}

	if (env.filterLeft == 0) {
		DEBUG(@"done writing %zu bytes, closing fd %d", [env.filterInput length], fd);
		// XXX: Do not in either case close the underlying native socket without invalidating the CFSocket object.
		CFSocketInvalidate(s);
		// close(ctx->fd);
		// ctx->fd = -1;
	} else
		CFSocketEnableCallBacks(s, kCFSocketWriteCallBack);
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
 
	if (filterReadFailed || filterWriteFailed)
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
	filterInput = nil;
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

	filterOutput = [NSMutableData dataWithCapacity:[inputText length]];
	filterInput = [inputText dataUsingEncoding:NSUTF8StringEncoding];
	filterLeft = [filterInput length];
	filterPtr = [filterInput bytes];
	filterDone = NO;
	filterReadFailed = NO;
	filterWriteFailed = NO;

	filterTarget = target;
	filterSelector = selector;
	filterContextInfo = contextInfo;


	int fd = [[shellOutput fileHandleForReading] fileDescriptor];
	int flags = fcntl(fd, F_GETFL, 0);
	fcntl(fd, F_SETFL, flags | O_NONBLOCK);

	inputContext.version = 0;
	inputContext.info = self; /* user data passed to the callbacks */
	inputContext.retain = NULL;
	inputContext.release = NULL;
	inputContext.copyDescription = NULL;

	inputSocket = CFSocketCreateWithNative(
		kCFAllocatorDefault,
		fd,
		kCFSocketReadCallBack,
		filter_read,
		&inputContext);
	if (inputSocket == NULL) {
		INFO(@"failed to create input CFSocket of fd %i", fd);
		return;
	}

	inputSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, inputSocket, 0);




	fd = [[shellInput fileHandleForWriting] fileDescriptor];
	flags = fcntl(fd, F_GETFL, 0);
        fcntl(fd, F_SETFL, flags | O_NONBLOCK);

	outputContext.version = 0;
	outputContext.info = self; /* user data passed to the callbacks */
	outputContext.retain = NULL;
	outputContext.release = NULL;
	outputContext.copyDescription = NULL;

	outputSocket = CFSocketCreateWithNative(
		kCFAllocatorDefault,
		fd,
		kCFSocketWriteCallBack,
		filter_write,
		&outputContext);
	if (outputSocket == NULL) {
		INFO(@"failed to create output CFSocket of fd %i", fd);
		return;
	}

	outputSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, outputSocket, 0);



	/* schedule the read and write sources in the new runloop mode */
	CFRunLoopAddSource(CFRunLoopGetCurrent(), inputSource, (CFStringRef)mode);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), outputSource, (CFStringRef)mode);

	NSDate *limitDate = [NSDate dateWithTimeIntervalSinceNow:2.0];

	int done = 0;

	for (;;) {
		[[NSRunLoop currentRunLoop] runMode:mode beforeDate:limitDate];
		if ([limitDate timeIntervalSinceNow] <= 0) {
			DEBUG(@"limit date %@ reached", limitDate);
			break;
		}

		if (filterReadFailed || filterWriteFailed) {
			DEBUG(@"%s", "input or output failed");
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
		CFRunLoopAddSource(CFRunLoopGetCurrent(), inputSource, kCFRunLoopCommonModes);
		CFRunLoopAddSource(CFRunLoopGetCurrent(), outputSource, kCFRunLoopCommonModes);
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
	NSUInteger line;

	if (command.addr2->type == EX_ADDR_ABS)
		line = command.addr2->addr.abs.line;
	else if (command.addr1->type == EX_ADDR_ABS)
		line = command.addr1->addr.abs.line;
	else {
		[self message:@"Not implemented."];
		return;
	}

	if (![exTextView gotoLine:line column:0])
		[self message:@"Movement past the end-of-file"];
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

		@"showguide", @"sg",
		@"guidecolumn", @"gc",

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
		nil];

	NSArray *booleans = [NSArray arrayWithObjects:
	    @"autoindent", @"expandtab", @"smartpair", @"ignorecase", @"smartcase", @"number",
	    @"autocollapse", @"hidetab", @"showguide", @"searchincr", @"smartindent",
	    @"wrap", @"antialias", @"list", nil];
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
	if ([command.command->name isEqualToString:@"buffer"]) {
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
		INFO(@"matches: %@", matches);
		return NO;
	}

	ViDocumentView *docView = viewController;
	[[docView document] setLanguage:[matches anyObject]];
	return YES;
}

@end

