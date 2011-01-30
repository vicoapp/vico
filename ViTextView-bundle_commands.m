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
#import "ViBundleCommand.h"

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

- (NSString *)inputOfType:(NSString *)type command:(ViBundleCommand *)command range:(NSRange *)rangePtr
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
		*rangePtr = [self trackScopeSelector:[command scope] atLocation:[self caret]];
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

- (NSString*)inputForCommand:(ViBundleCommand *)command range:(NSRange *)rangePtr
{
	NSString *inputText = [self inputOfType:[command input] command:command range:rangePtr];
	if (inputText == nil)
		inputText = [self inputOfType:[command fallbackInput] command:command range:rangePtr];

	return inputText;
}

- (void)performBundleCommand:(id)sender
{
	ViBundleCommand *command = sender;
	if ([sender respondsToSelector:@selector(representedObject)])
		command = [sender representedObject];

	/* FIXME: * If in input mode, should setup repeat text and such...
	 */

	/*  FIXME: need to verify correct behaviour of these env.variables
	 * cf. http://www.e-texteditor.com/forum/viewtopic.php?t=1644
	 */
	NSRange inputRange;
	NSString *inputText = [self inputForCommand:command range:&inputRange];

	// FIXME: beforeRunningCommand

	char *templateFilename = NULL;
	int fd = -1;

	NSString *shellCommand = [command command];
	if ([shellCommand hasPrefix:@"#!"]) {
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

	NSMutableDictionary *env = [[NSMutableDictionary alloc] init];
	[ViBundle setupEnvironment:env forTextView:self];

	/* Additional bundle command specific variables. */
	[env setObject:[[command bundle] path] forKey:@"TM_BUNDLE_PATH"];
	NSString *bundleSupportPath = [[command bundle] supportPath];
	[env setObject:bundleSupportPath forKey:@"TM_BUNDLE_SUPPORT"];

	NSString *supportPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Resources/Support"];
	char *path = getenv("PATH");
	[env setObject:[NSString stringWithFormat:@"%s:%@:%@",
	      path,
	      [supportPath stringByAppendingPathComponent:@"bin"],
	      [bundleSupportPath stringByAppendingPathComponent:@"bin"]]
	    forKey:@"PATH"];

	[task setCurrentDirectoryPath:[[[[self delegate] environment] baseURL] path]];
	[task setEnvironment:env];

	INFO(@"environment: %@", env);
	INFO(@"launching task command line [%@ %@]", [task launchPath], [[task arguments] componentsJoinedByString:@" "]);

	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:command, @"command", [NSValue valueWithRange:inputRange], @"inputRange", nil];
	INFO(@"contextInfo = %p", info);
	[[[self delegate] environment] filterText:inputText throughTask:task target:self selector:@selector(bundleCommandFinishedWithStatus:standardOutput:contextInfo:) contextInfo:info displayTitle:[command name]];

	if (fd != -1) {
		unlink(templateFilename);
		close(fd);
		free(templateFilename);
	}
}

- (void)bundleCommandFinishedWithStatus:(int)status standardOutput:(NSString *)outputText contextInfo:(id)contextInfo
{
	INFO(@"contextInfo = %p", contextInfo);
	NSDictionary *info = contextInfo;
	ViBundleCommand *command = [info objectForKey:@"command"];
	NSRange inputRange = [[info objectForKey:@"inputRange"] rangeValue];

	INFO(@"command %@ finished with status %i", [command name], status);

	NSString *outputFormat = [command output];

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
		[[self delegate] message:@"%@: exited with status %i", [command name], status];
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
		} else if ([outputFormat isEqualToString:@"insertAsText"] || [outputFormat isEqualToString:@"afterSelectedText"]) {
			[self insertString:outputText atLocation:[self caret] undoGroup:NO];
			[self setCaret:[self caret] + [outputText length]];
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
}

@end

