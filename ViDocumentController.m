#import "ViDocumentController.h"
#import "ViDocument.h"
#import "SFTPConnectionPool.h"
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

/*
 * Called by Cocoa when the whole application should close.
 */
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







- (void)closeNextDocumentInSet:(NSMutableSet *)set force:(BOOL)force
{
	ViDocument *doc = [set anyObject];
	if (doc == nil) {
		[self callCloseAllDelegateShouldTerminate:YES];
		return;
	}

	NSWindow *window = [[doc windowController] window];

	if (force || [window attachedSheet] == nil) {
		[[doc windowController] selectDocument:doc];
		/* 
		 * Schedule next close sheet in the event loop right after the windowcontroller has selected the document.
		 */
		SEL sel = @selector(canCloseDocumentWithDelegate:shouldCloseSelector:contextInfo:);
		SEL closeSelector = @selector(document:shouldCloseForSet:contextInfo:);
		void *contextInfo = NULL;
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[doc methodSignatureForSelector:sel]];
		[invocation setSelector:sel];
		[invocation setArgument:&self atIndex:2];
		[invocation setArgument:&closeSelector atIndex:3];
		[invocation setArgument:&contextInfo atIndex:4];
		[invocation performSelector:@selector(invokeWithTarget:) withObject:doc afterDelay:0.0];
	} else
		[[NSNotificationCenter defaultCenter] addObserver:self
							 selector:@selector(windowDidEndSheetForSet:)
							     name:NSWindowDidEndSheetNotification
							   object:window];
}

- (void)windowDidEndSheetForSet:(NSNotification *)notification
{
	NSWindow *window = [notification object];
	[[NSNotificationCenter defaultCenter] removeObserver:self
							name:NSWindowDidEndSheetNotification
						      object:window];

	[self closeNextDocumentInSet:closeAllSet force:YES];
}

- (void)document:(NSDocument *)doc shouldCloseForSet:(BOOL)shouldClose contextInfo:(void *)contextInfo
{
	if (!shouldClose) {
		[self callCloseAllDelegateShouldTerminate:NO];
		return;
	}

	[doc close];
	[closeAllSet removeObject:doc];
	[self closeNextDocumentInSet:closeAllSet force:NO];
}

/*
 * Called by a ViWindowController when it wants to close a set of documents.
 */
- (void)closeAllDocumentsInSet:(NSMutableSet *)set
		  withDelegate:(id)delegate
	   didCloseAllSelector:(SEL)didCloseAllSelector
		   contextInfo:(void *)contextInfo
{
	closeAllSet = set;
	closeAllDelegate = delegate;
	closeAllSelector = didCloseAllSelector;
	closeAllContextInfo = contextInfo;

	[self closeNextDocumentInSet:set force:NO];
}













- (IBAction)closeCurrentDocument:(id)sender
{
	[[ViWindowController currentWindowController] closeCurrentView];
}

- (NSInteger)runModalOpenPanel:(NSOpenPanel *)openPanel forTypes:(NSArray *)extensions
{
	[openPanel setCanChooseDirectories:YES];
	return [super runModalOpenPanel:openPanel forTypes:extensions];
}

- (NSString *)typeForContentsOfURL:(NSURL *)url error:(NSError **)outError
{
	BOOL isDirectory;
	if ([url isFileURL]) {
		if ([[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDirectory] && isDirectory)
			return @"Project";
	} else if ([[url scheme] isEqualToString:@"sftp"]) {
		SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:url error:outError];
		if ([conn fileExistsAtPath:[url path] isDirectory:&isDirectory error:outError] && isDirectory)
			return @"Project";
	}

	return @"Document";
}

@end

