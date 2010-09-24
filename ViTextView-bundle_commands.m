#include <sys/time.h>
#include <sys/types.h>
#include <sys/stat.h>

#import "ViTextView.h"
#import "ViCommandOutputController.h"
#import "ViDocument.h"  // for declaration of the message: method
#import "NSArray-patterns.h"
#import "NSTextStorage-additions.h"
#import "NSString-scopeSelector.h"

@implementation ViTextView (bundleCommands)

- (NSString *)bestMatchingScope:(NSArray *)scopeSelectors atLocation:(NSUInteger)aLocation
{
	NSArray *scopes = [self scopesAtLocation:aLocation];
	NSString *foundScopeSelector = nil;
	NSString *scopeSelector;
	u_int64_t highest_rank = 0;

	for (scopeSelector in scopeSelectors) {
		u_int64_t rank = [scopeSelector matchesScopes:scopes];
		if (rank > highest_rank) {
			foundScopeSelector = scopeSelector;
			highest_rank = rank;
		}
	}

	return foundScopeSelector;
}

- (NSRange)trackScopes:(NSArray *)trackScopes forward:(BOOL)forward fromLocation:(NSUInteger)aLocation
{
	NSArray *lastScopes = nil, *scopes;
	NSUInteger i = aLocation;
	for (;;) {
		if (forward && i >= [[self textStorage] length])
			break;
		else if (!forward && i == 0)
			break;

		if (!forward)
			i--;

		if ((scopes = [self scopesAtLocation:i]) == nil)
			break;

		if (lastScopes != scopes && ![trackScopes matchesScopes:scopes]) {
			if (!forward)
				i++;
			break;
		}

		if (forward)
			i++;

		lastScopes = scopes;
	}

	if (forward)
		return NSMakeRange(aLocation, i - aLocation);
	else
		return NSMakeRange(i, aLocation - i);
}

- (NSRange)trackScopeSelector:(NSString *)scopeSelector forward:(BOOL)forward fromLocation:(NSUInteger)aLocation
{
	return [self trackScopes:[scopeSelector componentsSeparatedByString:@" "] forward:forward fromLocation:aLocation];
}

- (NSRange)trackScopes:(NSArray *)scopes atLocation:(NSUInteger)aLocation
{
	NSRange rb = [self trackScopes:scopes forward:NO fromLocation:aLocation];
	NSRange rf = [self trackScopes:scopes forward:YES fromLocation:aLocation];
	return NSUnionRange(rb, rf);
}

- (NSRange)trackScopeSelector:(NSString *)scopeSelector atLocation:(NSUInteger)aLocation
{
	return [self trackScopes:[scopeSelector componentsSeparatedByString:@" "] atLocation:aLocation];
}

- (NSString *)inputOfType:(NSString *)type command:(NSDictionary *)command range:(NSRange *)rangePtr
{
	NSString *inputText = nil;

	if ([type isEqualToString:@"selection"])
	{
		NSRange sel = [self selectedRange];
		if (sel.length > 0)
		{
			*rangePtr = sel;
			inputText = [[[self textStorage] string] substringWithRange:*rangePtr];
		}
	}
	else if ([type isEqualToString:@"document"])
	{
		inputText = [[self textStorage] string];
		*rangePtr = NSMakeRange(0, [[self textStorage] length]);
	}
	else if ([type isEqualToString:@"scope"])
	{
		*rangePtr = [self trackScopeSelector:[command objectForKey:@"scope"] atLocation:[self caret]];
		inputText = [[[self textStorage] string] substringWithRange:*rangePtr];
	}
	else if ([type isEqualToString:@"none"])
	{
		inputText = @"";
		*rangePtr = NSMakeRange(0, 0);
	}
	else if ([type isEqualToString:@"word"])
	{
		inputText = [self wordAtLocation:[self caret] range:rangePtr];
	}

	return inputText;
}

- (NSString*)inputForCommand:(NSDictionary *)command range:(NSRange *)rangePtr
{
	NSString *inputText = [self inputOfType:[command objectForKey:@"input"] command:command range:rangePtr];
	if (inputText == nil)
		inputText = [self inputOfType:[command objectForKey:@"fallbackInput"] command:command range:rangePtr];

	return inputText;
}

- (void)setenv:(const char *)var value:(NSString *)value
{
	if (value)
		setenv(var, [value UTF8String], 1);
}

- (void)setenv:(const char *)var integer:(NSInteger)intValue
{
	[self setenv:var value:[NSString stringWithFormat:@"%li", intValue]];
}

- (void)setupEnvironmentForCommand:(NSDictionary *)command
{
	[self setenv:"TM_BUNDLE_PATH" value:[[command objectForKey:@"bundle"] path]];

	NSString *bundleSupportPath = [[command objectForKey:@"bundle"] supportPath];
	[self setenv:"TM_BUNDLE_SUPPORT" value:bundleSupportPath];

	NSString *supportPath = @"/Library/Application Support/TextMate/Support";
	[self setenv:"TM_SUPPORT_PATH" value:supportPath];

	char *path = getenv("PATH");
	[self setenv:"PATH" value:[NSString stringWithFormat:@"%s:%@:%@",
		path,
		[supportPath stringByAppendingPathComponent:@"bin"],
		[bundleSupportPath stringByAppendingPathComponent:@"bin"]]];

	[self setenv:"TM_CURRENT_LINE" value:[self lineForLocation:[self caret]]];
	[self setenv:"TM_CURRENT_WORD" value:[self wordAtLocation:[self caret]]];

	[self setenv:"TM_DIRECTORY" value:[[[self delegate] windowController] currentDirectory]];
	[self setenv:"TM_PROJECT_DIRECTORY" value:[[[self delegate] windowController] currentDirectory]];

	[self setenv:"TM_FILENAME" value:[[[[self delegate] fileURL] path] lastPathComponent]];
	[self setenv:"TM_FILEPATH" value:[[[self delegate] fileURL] path]];
	[self setenv:"TM_FULLNAME" value:NSFullUserName()];
	[self setenv:"TM_LINE_INDEX" integer:[self currentColumn]];
	[self setenv:"TM_LINE_NUMBER" integer:[self currentLine]];
	[self setenv:"TM_SCOPE" value:[[self scopesAtLocation:[self caret]] componentsJoinedByString:@" "]];

	// FIXME: TM_SELECTED_FILES
	// FIXME: TM_SELECTED_FILE
	[self setenv:"TM_SELECTED_TEXT" value:[[[self textStorage] string] substringWithRange:[self selectedRange]]];

	if ([[NSUserDefaults standardUserDefaults] integerForKey:@"expandtab"] == NSOnState)
		setenv("TM_SOFT_TABS", "YES", 1);
	else
		setenv("TM_SOFT_TABS", "NO", 1);

	[self setenv:"TM_TAB_SIZE" value:[[NSUserDefaults standardUserDefaults] stringForKey:@"shiftwidth"]];

	// FIXME: shellVariables in bundle preferences
}

- (void)performBundleCommand:(id)sender
{
	NSDictionary *command = [sender representedObject];
	INFO(@"command = %@", command);
	NSRange inputRange;

	/* FIXME: refactor ESC handling, and call it from here, ie both in insert and normal/visual mode, goto normal mode.
	 * If in input mode, should setup repeat text and such...
	 */
	[self setNormalMode];
	[self endUndoGroup];

	/*  FIXME: need to verify correct behaviour of these env.variables
	 * cf. http://www.e-texteditor.com/forum/viewtopic.php?t=1644
	 */
	NSString *inputText = [self inputForCommand:command range:&inputRange];
	[self setenv:"TM_INPUT_START_COLUMN" integer:[self columnAtLocation:inputRange.location]];
	[self setenv:"TM_INPUT_END_COLUMN" integer:[self columnAtLocation:NSMaxRange(inputRange)]];
	[self setenv:"TM_INPUT_START_LINE_INDEX" integer:[self columnAtLocation:inputRange.location]];
	[self setenv:"TM_INPUT_END_LINE_INDEX" integer:[self columnAtLocation:NSMaxRange(inputRange)]];
	[self setenv:"TM_INPUT_START_LINE" integer:[[self textStorage] lineNumberAtLocation:inputRange.location]];
	[self setenv:"TM_INPUT_END_LINE" integer:[[self textStorage] lineNumberAtLocation:NSMaxRange(inputRange)]];

	// FIXME: beforeRunningCommand

	char *templateFilename = NULL;
	int fd = -1;

	NSString *shellCommand = [command objectForKey:@"command"];
//	if ([shellCommand hasPrefix:@"#!"])
	{
		const char *tmpl = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"vibrant_cmd.XXXXXX"] fileSystemRepresentation];
		DEBUG(@"using template %s", tmpl);
		templateFilename = strdup(tmpl);
		fd = mkstemp(templateFilename);
		if (fd == -1)
		{
			NSLog(@"failed to open temporary file: %s", strerror(errno));
			return;
		}
		const char *data = [shellCommand UTF8String];
		ssize_t rc = write(fd, data, strlen(data));
		DEBUG(@"wrote %i byte", rc);
		if (rc == -1) {
			NSLog(@"Failed to save temporary command file: %s", strerror(errno));
			unlink(templateFilename);
			close(fd);
			free(templateFilename);
			return;
		}
		chmod(templateFilename, 0700);
		shellCommand = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:templateFilename length:strlen(templateFilename)];
	}

	INFO(@"input text = [%@]", inputText);

	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:@"/bin/bash"];
	[task setArguments:[NSArray arrayWithObjects:@"-c", shellCommand, nil]];

	id shellInput;
	if ([inputText length] > 0)
		shellInput = [NSPipe pipe];
	else
		shellInput = [NSFileHandle fileHandleWithNullDevice];
	NSPipe *shellOutput = [NSPipe pipe];

	[task setStandardInput:shellInput];
	[task setStandardOutput:shellOutput];
	/* FIXME: set standard error to standard output? */

	NSString *outputFormat = [command objectForKey:@"output"];

	[self setupEnvironmentForCommand:command];
	DEBUG(@"launching task command line [%@ %@]", [task launchPath], [[task arguments] componentsJoinedByString:@" "]);
	[task launch];
	if ([inputText length] > 0)
	{
		[[shellInput fileHandleForWriting] writeData:[inputText dataUsingEncoding:NSUTF8StringEncoding]];
		[[shellInput fileHandleForWriting] closeFile];
	}

	[task waitUntilExit];
	int status = [task terminationStatus];

	if (fd != -1)
	{
		unlink(templateFilename);
		close(fd);
		free(templateFilename);
	}

	if (status >= 200 && status <= 207)
	{
		NSArray *overrideOutputFormat = [NSArray arrayWithObjects:
			@"discard",
			@"replaceSelectedText", 
			@"replaceDocument", 
			@"insertAsText", 
			@"insertAsSnippet", 
			@"showAsHTML", 
			@"showAsTooltip", 
			@"createNewDocument", 
			nil];
		outputFormat = [overrideOutputFormat objectAtIndex:status - 200];
		status = 0;
	}

	if (status != 0)
	{
		[[self delegate] message:@"%@: exited with status %i", [command objectForKey:@"name"], status];
	}
	else
	{
		NSData *outputData = [[shellOutput fileHandleForReading] readDataToEndOfFile];
		NSString *outputText = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];

		INFO(@"command output: %@", outputText);

		if ([outputFormat isEqualToString:@"replaceSelectedText"])
			[self replaceRange:inputRange withString:outputText undoGroup:NO];
		else if ([outputFormat isEqualToString:@"showAsTooltip"])
		{
			[[self delegate] message:@"%@", [outputText stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
			// [self addToolTipRect: owner:outputText userData:nil];
		}
		else if ([outputFormat isEqualToString:@"showAsHTML"])
		{
			ViCommandOutputController *oc = [[ViCommandOutputController alloc] initWithHTMLString:outputText];
			[[oc window] makeKeyAndOrderFront:self];
		}
		else if ([outputFormat isEqualToString:@"insertAsSnippet"])
		{
			[self deleteRange:inputRange];
			[self setCaret:inputRange.location];
			activeSnippet = [self insertSnippet:outputText atLocation:[self caret]];
		}
		else if ([outputFormat isEqualToString:@"discard"])
			;
		else
			INFO(@"unknown output format: %@", outputFormat);
	}

	[self endUndoGroup];
}

@end

