#include <sys/time.h>
#include <sys/types.h>
#include <sys/stat.h>

#import "ViAppController.h"
#import "ViTextView.h"
#import "ViCommandOutputController.h"
#import "NSArray-patterns.h"
#import "NSString-scopeSelector.h"
#import "ViBundleCommand.h"
#import "ViBundleSnippet.h"
#import "ViWindowController.h"
#import "ViDocumentController.h"
#import "ViTaskRunner.h"

@implementation ViTextView (bundleCommands)


- (NSString *)inputOfType:(NSString *)type
                 command:(ViBundleCommand *)command
                   range:(NSRange *)rangePtr
{
	NSString *inputText = nil;

	if ([type isEqualToString:@"selection"]) {
		NSRange sel = [self selectedRange];
		if (sel.length > 0) {
			*rangePtr = sel;
			inputText = [[[self textStorage] string] substringWithRange:*rangePtr];
		}
	} else if ([type isEqualToString:@"document"] || type == nil) {
		inputText = [[self textStorage] string];
		*rangePtr = NSMakeRange(0, [[self textStorage] length]);
	} else if ([type isEqualToString:@"scope"]) {
		*rangePtr = [document rangeOfScopeSelector:[command scopeSelector] atLocation:[self caret]];
		inputText = [[[self textStorage] string] substringWithRange:*rangePtr];
	} else if ([type isEqualToString:@"word"]) {
		inputText = [[self textStorage] wordAtLocation:[self caret] range:rangePtr acceptAfter:YES];
	} else if ([type isEqualToString:@"line"]) {
		NSUInteger bol, eol;
		[self getLineStart:&bol end:NULL contentsEnd:&eol forLocation:[self caret]];
		*rangePtr = NSMakeRange(bol, eol - bol);
		inputText = [[[self textStorage] string] substringWithRange:*rangePtr];
	} else if ([type isEqualToString:@"character"]) {
		if ([self caret] < [[self textStorage] length]) {
			*rangePtr = NSMakeRange([self caret], 1);
			inputText = [[[self textStorage] string] substringWithRange:*rangePtr];
		}
	}

	return inputText;
}

- (NSString *)inputForCommand:(ViBundleCommand *)command
                       range:(NSRange *)rangePtr
{
	NSString *inputText = [self inputOfType:[command input]
	                                command:command
	                                  range:rangePtr];
	if (inputText == nil)
		inputText = [self inputOfType:[command fallbackInput]
		                      command:command
		                        range:rangePtr];

	if (inputText == nil) {
		inputText = @"";
		*rangePtr = NSMakeRange([self caret], 0);
	}

	return inputText;
}

- (void)performBundleCommand:(ViBundleCommand *)command
{
	/* If we got here via a tab trigger, first remove the tab trigger word.
	 */
	if ([command tabTrigger] && snippetMatchRange.location != NSNotFound) {
		[self deleteRange:snippetMatchRange];
		[self setCaret:snippetMatchRange.location];
		snippetMatchRange.location = NSNotFound;
	}

	NSRange inputRange;
	NSString *inputText = [self inputForCommand:command range:&inputRange];

	NSRange selectedRange;
	if ([[command input] isEqualToString:@"document"] ||
	    [[command input] isEqualToString:@"none"]) {
		selectedRange = [self selectedRange];
		if (selectedRange.length == 0)
			selectedRange = NSMakeRange([self caret], 0);
	} else
		selectedRange = inputRange;

	// FIXME: beforeRunningCommand

	char *templateFilename = NULL;
	int fd = -1;

	NSString *shellCommand = [command command];
	DEBUG(@"shell command = [%@]", shellCommand);
	if ([shellCommand hasPrefix:@"#!"]) {
		const char *tmpl = [[NSTemporaryDirectory()
		    stringByAppendingPathComponent:@"vico_cmd.XXXXXXXXXX"]
		    fileSystemRepresentation];
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
		NSFileManager *fm = [NSFileManager defaultManager];
		shellCommand = [fm stringWithFileSystemRepresentation:templateFilename
		                                               length:strlen(templateFilename)];
	}

	DEBUG(@"input text = [%@], range = %@", inputText, NSStringFromRange(inputRange));

	NSTask *task = [[NSTask alloc] init];
	if (templateFilename)
		[task setLaunchPath:shellCommand];
	else {
		[task setLaunchPath:@"/bin/bash"];
		[task setArguments:[NSArray arrayWithObjects:@"-c", shellCommand, nil]];
	}

	NSMutableDictionary *env = [NSMutableDictionary dictionary];
	[ViBundle setupEnvironment:env forTextView:self window:[self window] bundle:[command bundle]];
	[task setEnvironment:env];
	//DEBUG(@"environment: %@", env);

	NSURL *baseURL = [[document fileURL] URLByDeletingLastPathComponent];
	if ([baseURL isFileURL])
		[task setCurrentDirectoryPath:[baseURL path]];
	else
		[task setCurrentDirectoryPath:NSTemporaryDirectory()];

	DEBUG(@"launching task command line [%@ %@]",
	    [task launchPath], [[task arguments] componentsJoinedByString:@" "]);

	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
	    command, @"command",
	    [NSValue valueWithRange:inputRange], @"inputRange",
	    [NSValue valueWithRange:selectedRange], @"selectedRange",
	    nil];

	document.busy = YES;
	ViTaskRunner *runner = [[ViTaskRunner alloc] init];
	[runner launchTask:task
	 withStandardInput:[inputText dataUsingEncoding:NSUTF8StringEncoding]
     synchronouslyInWindow:[self window]
		     title:[command name]
		    target:self
		  selector:@selector(bundleCommand:finishedWithStatus:contextInfo:)
	       contextInfo:info];

	if (fd != -1) {
		unlink(templateFilename);
		close(fd);
		free(templateFilename);
	}
}

- (void)bundleCommand:(ViTaskRunner *)runner
   finishedWithStatus:(int)status
	  contextInfo:(id)contextInfo
{
	NSDictionary *info = contextInfo;
	ViBundleCommand *command = [info objectForKey:@"command"];
	NSRange inputRange = [[info objectForKey:@"inputRange"] rangeValue];
	NSRange selectedRange = [[info objectForKey:@"selectedRange"] rangeValue];
	NSString *outputText = [runner stdoutString];

	DEBUG(@"command %@ finished with status %i", [command name], status);
	document.busy = NO;

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

	if (status != 0) {
		MESSAGE(@"%@: exited with status %i", [command name], status);
		DEBUG(@"command output: %@", outputText);
	} else {
		DEBUG(@"command output: %@", outputText);
		DEBUG(@"output format: %@", outputFormat);

		if (mode == ViVisualMode)
			[self setNormalMode];

		if ([outputFormat isEqualToString:@"replaceSelectedText"])
			[self replaceRange:selectedRange withString:outputText];
		else if ([outputFormat isEqualToString:@"replaceDocument"])
			[self replaceRange:NSMakeRange(0, [[self textStorage] length]) withString:outputText];
		else if ([outputFormat isEqualToString:@"showAsTooltip"]) {
			MESSAGE(@"%@", [outputText stringByReplacingOccurrencesOfString:@"\n" withString:@" "]);
			// [self addToolTipRect: owner:outputText userData:nil];
		} else if ([outputFormat isEqualToString:@"showAsHTML"]) {
			id<ViViewController> viewController = [[[self window] windowController] currentView];
			ViTabController *tabController = [viewController tabController];
			id<ViViewController> webView = nil;
			/* Try to reuse any existing web view in the current tab. */
			for (webView in [tabController views]) {
				if ([webView isKindOfClass:[ViCommandOutputController class]])
					break;
			}

			BOOL splitVertically = NO;
			BOOL newWindow = NO;
			NSString *htmlMode = [command htmlMode];
			if (htmlMode == nil)
				htmlMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"defaultHTMLMode"];
			if ([htmlMode isEqualTo:@"split"])
				splitVertically = NO;
			else if ([htmlMode isEqualTo:@"vsplit"])
				splitVertically = YES;
			else if ([htmlMode isEqualTo:@"window"])
				newWindow = YES;

			if (webView) {
				[(ViCommandOutputController *)webView setContent:outputText];
				[(ViCommandOutputController *)webView setTitle:[command name]];
				[[[self window] windowController] selectDocumentView:webView];
			} else {
				ViCommandOutputController *oc = [[ViCommandOutputController alloc] initWithHTMLString:outputText];
				[oc setTitle:[command name]];

				if (newWindow) {
					ViWindowController *winCon = [[ViWindowController alloc] init];
					[winCon createTabWithViewController:oc];
					[winCon selectDocumentView:oc];
				} else {
					if (viewController) {
						[tabController splitView:viewController
								withView:oc
							      vertically:splitVertically];
					} else
						[[[self window] windowController] createTabWithViewController:oc];
					[[[self window] windowController] selectDocumentView:oc];
				}
			}
		} else if ([outputFormat isEqualToString:@"insertAsText"]) {
			[self insertString:outputText atLocation:[self caret]];
			[self setCaret:[self caret] + [outputText length]];
		} else if ([outputFormat isEqualToString:@"afterSelectedText"]) {
			[self insertString:outputText atLocation:NSMaxRange(selectedRange)];
			[self setCaret:NSMaxRange(selectedRange) + [outputText length]];
		} else if ([outputFormat isEqualToString:@"insertAsSnippet"]) {
			NSRange r;
			/*
			 * Seems TextMate replaces the snippet trigger range only
			 * if input type is not "selection" or any fallback (line, word, ...).
			 * Otherwise the selection is replaced... (?)
			 */
			if ([[command input] isEqualToString:@"document"] ||
			    [[command input] isEqualToString:@"none"]) {
				r = NSMakeRange([self caret], 0);
			} else {
				/* Replace the selection. */
				r = inputRange;
			}
			[self insertSnippet:outputText
			         fromBundle:[command bundle]
			            inRange:r];
		} else if ([outputFormat isEqualToString:@"openAsNewDocument"] ||
		           [outputFormat isEqualToString:@"createNewDocument"]) {
			id<ViViewController> viewController = [[[self window] windowController] splitVertically:NO
													andOpen:nil
											     orSwitchToDocument:nil];
			ViDocument *doc = [viewController document];
			[doc setString:outputText];
		} else if ([outputFormat isEqualToString:@"discard"])
			;
		else
			INFO(@"unknown output format: %@", outputFormat);
	}

	[self endUndoGroup];
}

- (void)performBundleItem:(id)bundleItem
{
	if ([bundleItem respondsToSelector:@selector(representedObject)])
		bundleItem = [bundleItem representedObject];

	if ([bundleItem isKindOfClass:[ViBundleCommand class]])
		[self performBundleCommand:bundleItem];
	else if ([bundleItem isKindOfClass:[ViBundleSnippet class]])
		[self performBundleSnippet:bundleItem];
}

/*
 * Performs one of possibly multiple matching bundle items (commands or snippets).
 * Show a menu of choices if more than one match.
 */
- (void)performBundleItems:(NSArray *)matches
{
	if ([matches count] == 1) {
		[self performBundleItem:[matches objectAtIndex:0]];
	} else if ([matches count] > 1) {
		NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Bundle commands"];
		[menu setAllowsContextMenuPlugIns:NO];
		int quickindex = 1;
		for (ViBundleItem *c in matches) {
			NSString *key = @"";
			if (quickindex <= 10)
				key = [NSString stringWithFormat:@"%i", quickindex % 10];
			NSMenuItem *item = [menu addItemWithTitle:[c name]
			                                   action:@selector(performBundleItem:)
			                            keyEquivalent:key];
			[item setKeyEquivalentModifierMask:0];
			[item setRepresentedObject:c];
			++quickindex;
		}

		NSPoint point = [[self layoutManager] boundingRectForGlyphRange:NSMakeRange([self caret], 0)
		                                                inTextContainer:[self textContainer]].origin;
		NSEvent *ev = [NSEvent mouseEventWithType:NSRightMouseDown
				  location:[self convertPoint:point toView:nil]
			     modifierFlags:0
				 timestamp:[[NSDate date] timeIntervalSinceNow]
			      windowNumber:[[self window] windowNumber]
				   context:[NSGraphicsContext currentContext]
			       eventNumber:0
				clickCount:1
				  pressure:1.0];
		[NSMenu popUpContextMenu:menu withEvent:ev forView:self];
	}
}

@end

