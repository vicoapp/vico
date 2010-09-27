#import "ViDocumentController.h"
#import "ViDocument.h"
#include "logging.h"

@implementation ViDocumentController

- (void)callCloseAllDelegateShouldTerminate:(BOOL)flag
{
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[closeAllDelegate methodSignatureForSelector:closeAllSelector]];
	[invocation setSelector:closeAllSelector];
	[invocation setArgument:&self atIndex:2];
	[invocation setArgument:&flag atIndex:3];
	[invocation setArgument:&closeAllContextInfo atIndex:4];
	[invocation invokeWithTarget:closeAllDelegate];
}

- (void)closeNextDocumentInWindow:(NSWindow *)window
{
	if (window != nil && closeAllWindows && [[(ViWindowController *)[window windowController] documents] count] == 0)
		window = nil;	/* Proceed with next window. */

	ViWindowController *windowController = nil;
	if (window == nil) {
		if ([[self documents] count] > 0)
			windowController = [[[self documents] objectAtIndex:0] windowController];
	} else
		windowController = [window windowController];

	if ([[windowController documents] count] > 0) {
		ViDocument *doc = [[windowController documents] objectAtIndex:0];
		[windowController selectDocument:doc];
		[doc canCloseDocumentWithDelegate:self
			      shouldCloseSelector:@selector(document:shouldClose:contextInfo:)
				      contextInfo:NULL];
	} else
		[self callCloseAllDelegateShouldTerminate:YES];
}

- (void)windowDidEndSheet:(NSNotification *)notification
{
	NSWindow *window = [notification object];
	[[NSNotificationCenter defaultCenter] removeObserver:self
							name:NSWindowDidEndSheetNotification
						      object:window];

	[self closeNextDocumentInWindow:window];
}

- (void)document:(NSDocument *)doc
     shouldClose:(BOOL)shouldClose
     contextInfo:(void *)contextInfo
{
	if (!shouldClose) {
		[self callCloseAllDelegateShouldTerminate:NO];
		return;
	}

	[doc close];

	NSWindow *window = [[(ViDocument *)doc windowController] window];
	if ([window attachedSheet] == nil)
		[self closeNextDocumentInWindow:window];
	else
		[[NSNotificationCenter defaultCenter] addObserver:self
							 selector:@selector(windowDidEndSheet:)
							     name:NSWindowDidEndSheetNotification
							   object:window];
}

- (void)closeAllDocumentsWithDelegate:(id)delegate
		  didCloseAllSelector:(SEL)didCloseAllSelector
			  contextInfo:(void *)contextInfo
{
	closeAllDelegate = delegate;
	closeAllSelector = didCloseAllSelector;
	closeAllContextInfo = contextInfo;
	closeAllWindows = YES;
	[self closeNextDocumentInWindow:nil];
}

- (void)closeAllDocumentsInWindow:(NSWindow *)window
		     withDelegate:(id)delegate
	      didCloseAllSelector:(SEL)didCloseAllSelector
{
	closeAllDelegate = delegate;
	closeAllSelector = didCloseAllSelector;
	closeAllContextInfo = NULL;
	closeAllWindows = NO;

	if ([window attachedSheet] == nil)
		[self closeNextDocumentInWindow:window];
	else
		[[NSNotificationCenter defaultCenter] addObserver:self
							 selector:@selector(windowDidEndSheet:)
							     name:NSWindowDidEndSheetNotification
							   object:window];
}

- (IBAction)closeCurrentDocument:(id)sender
{
	ViWindowController *wc = [ViWindowController currentWindowController];
	[wc closeDocument:[wc currentDocument]];
}

- (NSInteger)runModalOpenPanel:(NSOpenPanel *)openPanel forTypes:(NSArray *)extensions
{
	[openPanel setCanChooseDirectories:YES];
	return [super runModalOpenPanel:openPanel forTypes:extensions];
}

- (NSString *)typeForContentsOfURL:(NSURL *)inAbsoluteURL error:(NSError **)outError
{
	BOOL isDirectory;
	if ([inAbsoluteURL isFileURL] &&
	    [[NSFileManager defaultManager] fileExistsAtPath:[inAbsoluteURL path]
						 isDirectory:&isDirectory] &&
	    isDirectory)
		return @"Project";
	return @"Document";
}

@end

