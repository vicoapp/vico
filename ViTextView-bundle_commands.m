#include <sys/time.h>
#include <sys/types.h>
#include <sys/stat.h>

#import "ViAppController.h"
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
	return [scopeSelectors bestMatchForScopes:scopes];
}

- (NSRange)trackScopeSelector:(NSString *)scopeSelector forward:(BOOL)forward fromLocation:(NSUInteger)aLocation
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

		if (lastScopes != scopes && ![scopeSelector matchesScopes:scopes]) {
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

- (NSRange)trackScopeSelector:(NSString *)scopeSelector atLocation:(NSUInteger)aLocation
{
	NSRange rb = [self trackScopeSelector:scopeSelector forward:NO fromLocation:aLocation];
	NSRange rf = [self trackScopeSelector:scopeSelector forward:YES fromLocation:aLocation];
	return NSUnionRange(rb, rf);
}

- (NSString *)inputOfType:(NSString *)type command:(NSDictionary *)command range:(NSRange *)rangePtr
{
	NSString *inputText = nil;

	if ([type isEqualToString:@"selection"]) {
		NSRange sel = [self selectedRange];
		if (sel.length > 0) {
			*rangePtr = sel;
			inputText = [[[self textStorage] string] substringWithRange:*rangePtr];
		}
	} else if ([type isEqualToString:@"document"]) {
		inputText = [[self textStorage] string];
		*rangePtr = NSMakeRange(0, [[self textStorage] length]);
	} else if ([type isEqualToString:@"scope"]) {
		*rangePtr = [self trackScopeSelector:[command objectForKey:@"scope"] atLocation:[self caret]];
		inputText = [[[self textStorage] string] substringWithRange:*rangePtr];
	} else if ([type isEqualToString:@"none"]) {
		inputText = @"";
		*rangePtr = NSMakeRange(0, 0);
	} else if ([type isEqualToString:@"word"])
		inputText = [[self textStorage] wordAtLocation:[self caret] range:rangePtr];
	else if ([type isEqualToString:@"line"]) {
		NSUInteger bol, eol;
		[self getLineStart:&bol end:NULL contentsEnd:&eol forLocation:[self caret]];
		*rangePtr = NSMakeRange(bol, eol - bol);
		inputText = [[[self textStorage] string] substringWithRange:*rangePtr];
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

- (void)setVariable:(NSString *)var inEnvironment:(NSMutableDictionary *)env value:(NSString *)value
{
	if (value)
		[env setObject:value forKey:var];
}

- (void)setVariable:(NSString *)var inEnvironment:(NSMutableDictionary *)env integer:(NSInteger)intValue
{
	[env setObject:[NSString stringWithFormat:@"%li", intValue] forKey:var];
}

- (void)setupEnvironment:(NSMutableDictionary *)env forCommand:(NSDictionary *)command
{
	[self setVariable:@"TM_BUNDLE_PATH" inEnvironment:env value:[[command objectForKey:@"bundle"] path]];

	NSString *bundleSupportPath = [[command objectForKey:@"bundle"] supportPath];
	[self setVariable:@"TM_BUNDLE_SUPPORT" inEnvironment:env value:bundleSupportPath];

	NSString *supportPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Resources/Support"];
	[self setVariable:@"TM_SUPPORT_PATH" inEnvironment:env value:supportPath];

	char *path = getenv("PATH");
	[self setVariable:@"PATH" inEnvironment:env value:[NSString stringWithFormat:@"%s:%@:%@",
		path,
		[supportPath stringByAppendingPathComponent:@"bin"],
		[bundleSupportPath stringByAppendingPathComponent:@"bin"]]];

	[self setVariable:@"TM_CURRENT_LINE" inEnvironment:env value:[[self textStorage] lineForLocation:[self caret]]];
	[self setVariable:@"TM_CURRENT_WORD" inEnvironment:env value:[[self textStorage] wordAtLocation:[self caret]]];

	NSURL *url = [[[self delegate] environment] baseURL];
	NSString *cwd = nil;
	if ([url isFileURL])
		cwd = [[[[self delegate] environment] baseURL] path];
	else
		cwd = [[[[self delegate] environment] baseURL] absoluteString];
	[self setVariable:@"TM_DIRECTORY" inEnvironment:env value:cwd];
	[self setVariable:@"TM_PROJECT_DIRECTORY" inEnvironment:env value:cwd];

	[self setVariable:@"TM_FILENAME" inEnvironment:env value:[[[[self delegate] fileURL] path] lastPathComponent]];
	url = [[self delegate] fileURL];
	if ([url isFileURL])
		[self setVariable:@"TM_FILEPATH" inEnvironment:env value:[url path]];
	else
		[self setVariable:@"TM_FILEPATH" inEnvironment:env value:[url absoluteString]];
	[self setVariable:@"TM_FULLNAME" inEnvironment:env value:NSFullUserName()];
	[self setVariable:@"TM_LINE_INDEX" inEnvironment:env integer:[[self textStorage] lineIndexAtLocation:[self caret]]];
	[self setVariable:@"TM_LINE_NUMBER" inEnvironment:env integer:[self currentLine]];
	[self setVariable:@"TM_SCOPE" inEnvironment:env value:[[self scopesAtLocation:[self caret]] componentsJoinedByString:@" "]];

	// FIXME: TM_SELECTED_FILES
	// FIXME: TM_SELECTED_FILE
	[self setVariable:@"TM_SELECTED_TEXT" inEnvironment:env value:[[[self textStorage] string] substringWithRange:[self selectedRange]]];

	if ([[NSUserDefaults standardUserDefaults] integerForKey:@"expandtab"] == NSOnState)
		[env setObject:@"YES" forKey:@"TM_SOFT_TABS" ];
	else
		[env setObject:@"NO" forKey:@"TM_SOFT_TABS" ];

	[self setVariable:@"TM_TAB_SIZE" inEnvironment:env value:[[NSUserDefaults standardUserDefaults] stringForKey:@"shiftwidth"]];

	[env setObject:NSHomeDirectory() forKey:@"HOME"];

	// FIXME: shellVariables in bundle preferences
}

- (void)performBundleCommand:(id)sender
{
	NSDictionary *command = sender;
	if ([sender respondsToSelector:@selector(representedObject)])
		command = [sender representedObject];
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

	// FIXME: beforeRunningCommand

	char *templateFilename = NULL;
	int fd = -1;

	NSString *shellCommand = [command objectForKey:@"command"];
	if ([shellCommand hasPrefix:@"#!"])
	{
		const char *tmpl = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"vibrant_cmd.XXXXXX"] fileSystemRepresentation];
		DEBUG(@"using template %s", tmpl);
		templateFilename = strdup(tmpl);
		fd = mkstemp(templateFilename);
		if (fd == -1) {
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

	DEBUG(@"input text = [%@]", inputText);

	NSTask *task = [[NSTask alloc] init];
	if (templateFilename)
		[task setLaunchPath:shellCommand];
	else {
		[task setLaunchPath:@"/bin/bash"];
		[task setArguments:[NSArray arrayWithObjects:@"-c", shellCommand, nil]];
	}

	id shellInput;
	if ([inputText length] > 0)
		shellInput = [NSPipe pipe];
	else
		shellInput = [NSFileHandle fileHandleWithNullDevice];
	NSPipe *shellOutput = [NSPipe pipe];

	[task setStandardInput:shellInput];
	[task setStandardOutput:shellOutput];
	/* FIXME: set standard error to standard output? */

	NSMutableDictionary *env = [[NSMutableDictionary alloc] init];
	[self setupEnvironment:env forCommand:command];
	[self setVariable:@"TM_INPUT_START_COLUMN" inEnvironment:env integer:[[self textStorage] columnAtLocation:inputRange.location]];
	[self setVariable:@"TM_INPUT_END_COLUMN" inEnvironment:env integer:[[self textStorage] columnAtLocation:NSMaxRange(inputRange)]];
	[self setVariable:@"TM_INPUT_START_LINE_INDEX" inEnvironment:env integer:[[self textStorage] columnAtLocation:inputRange.location]];
	[self setVariable:@"TM_INPUT_END_LINE_INDEX" inEnvironment:env integer:[[self textStorage] columnAtLocation:NSMaxRange(inputRange)]];
	[self setVariable:@"TM_INPUT_START_LINE" inEnvironment:env integer:[[self textStorage] lineNumberAtLocation:inputRange.location]];
	[self setVariable:@"TM_INPUT_END_LINE" inEnvironment:env integer:[[self textStorage] lineNumberAtLocation:NSMaxRange(inputRange)]];
	[task setCurrentDirectoryPath:[[[[self delegate] environment] baseURL] path]];
	[task setEnvironment:env];

	INFO(@"environment: %@", env);
	INFO(@"launching task command line [%@ %@]", [task launchPath], [[task arguments] componentsJoinedByString:@" "]);

	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:command, @"command", [NSValue valueWithRange:inputRange], @"inputRange", nil];
	INFO(@"contextInfo = %p", info);
	[[[self delegate] environment] filterText:inputText throughTask:task target:self selector:@selector(bundleCommandFinishedWithStatus:standardOutput:contextInfo:) contextInfo:info];

	if (fd != -1) {
		unlink(templateFilename);
		close(fd);
		free(templateFilename);
	}
}

- (void)bundleCommandFinishedWithStatus:(int)status standardOutput:(NSString *)outputText contextInfo:(void *)contextInfo
{
	INFO(@"contextInfo = %p", contextInfo);
	NSDictionary *info = contextInfo;
	NSDictionary *command = [info objectForKey:@"command"];
	NSRange inputRange = [[info objectForKey:@"inputRange"] rangeValue];

	INFO(@"command %@ finished with status %i", [command objectForKey:@"name"], status);

	NSString *outputFormat = [command objectForKey:@"output"];

	if (status >= 200 && status <= 207) {
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
		[[self delegate] message:@"%@: exited with status %i", [command objectForKey:@"name"], status];
	else {
		DEBUG(@"command output: %@", outputText);

		if ([outputFormat isEqualToString:@"replaceSelectedText"])
			[self replaceRange:inputRange withString:outputText undoGroup:NO];
		else if ([outputFormat isEqualToString:@"showAsTooltip"]) {
			[[self delegate] message:@"%@", [outputText stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
			// [self addToolTipRect: owner:outputText userData:nil];
		} else if ([outputFormat isEqualToString:@"showAsHTML"]) {
			ViCommandOutputController *oc = [[ViCommandOutputController alloc] initWithHTMLString:outputText];
			[[oc window] makeKeyAndOrderFront:self];
		} else if ([outputFormat isEqualToString:@"insertAsSnippet"]) {
			[self deleteRange:inputRange];
			[self setCaret:inputRange.location];
			[[self delegate] setActiveSnippet:[self insertSnippet:outputText atLocation:inputRange.location]];
			[self setInsertMode:nil];
			[self setCaret:final_location];
		} else if ([outputFormat isEqualToString:@"openAsNewDocument"]) {
			ViDocument *doc = [[[self delegate] environment] splitVertically:NO andOpen:nil orSwitchToDocument:nil];
			[doc setString:outputText];
		} else if ([outputFormat isEqualToString:@"discard"])
			;
		else
			INFO(@"unknown output format: %@", outputFormat);
	}

	[self endUndoGroup];
}

@end

