#import "ViDocumentController.h"
#import "ViDocumentTabController.h"
#import "ViDocument.h"
#import "ViDocumentView.h"
#import "SFTPConnectionPool.h"
#import "NSObject+SPInvocationGrabbing.h"
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
		SEL closeSelector = @selector(document:shouldCloseForSet:contextInfo:);
		[[doc nextRunloop] canCloseDocumentWithDelegate:self
		                            shouldCloseSelector:closeSelector
		                                    contextInfo:NULL];
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





- (NSURL *)normalizePath:(NSString *)filename
              relativeTo:(NSURL *)relURL
                   error:(NSError **)outError
{
	if (relURL ==  nil)
		relURL = [(ExEnvironment *)[[ViWindowController currentWindowController] environment] baseURL];

	NSString *escapedFilename = [filename stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSURL *url = [NSURL URLWithString:escapedFilename];
	if (url == nil || [url scheme] == nil) {
		NSString *path = escapedFilename;
		if ([path hasPrefix:@"~"]) {
			if (relURL == nil || [relURL isFileURL])
				path = [path stringByExpandingTildeInPath];
			else {
				SFTPConnection *conn = [[SFTPConnectionPool sharedPool]
				    connectionWithURL:relURL error:outError];
				if (conn == nil)
					return nil;
				path = [path stringByReplacingCharactersInRange:NSMakeRange(0, 1)
								     withString:[conn home]];
			}
		}
		url = [NSURL URLWithString:path relativeToURL:relURL];
	}

	return [url absoluteURL];
}


- (ViDocument *)openDocument:(id)filenameOrURL
                  andDisplay:(BOOL)display
              allowDirectory:(BOOL)allowDirectory
{
	ViWindowController *windowController = [ViWindowController currentWindowController];
	NSError *error = nil;
	NSURL *url;
	if ([filenameOrURL isKindOfClass:[NSURL class]])
		url = filenameOrURL;
	else
		url = [self normalizePath:filenameOrURL relativeTo:nil error:&error];

	if (url == nil) {
		if (error)
			[windowController message:@"%@: %@",
			    filenameOrURL, [error localizedDescription]];
		return nil;
	}

	BOOL isDirectory = NO;
	BOOL exists = NO;
	if ([url isFileURL])
		exists = [[NSFileManager defaultManager] fileExistsAtPath:[url path]
							      isDirectory:&isDirectory];
	else {
		SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:url error:&error];
		exists = [conn fileExistsAtPath:[url path] isDirectory:&isDirectory error:&error];
		if (error) {
			[windowController message:@"%@: %@",
			    [url absoluteString], [error localizedDescription]];
			return nil;
		}
	}

	if (isDirectory && !allowDirectory) {
		[windowController message:@"%@: is a directory", [url absoluteString]];
		return nil;
	}

	ViDocument *doc;
	if (exists) {
		doc = [self openDocumentWithContentsOfURL:url
						  display:display
						    error:&error];
	} else {
		doc = [self openUntitledDocumentAndDisplay:display
						     error:&error];
		[doc setIsTemporary:YES];
		[doc setFileURL:url];
	}

	if (error) {
		[windowController message:@"%@: %@",
		    [url absoluteString], [error localizedDescription]];
		return nil;
	}

	if (!display) {
		[doc addWindowController:windowController];
		[windowController addDocument:doc];
	}

	return doc;
}

- (ViDocument *)splitVertically:(BOOL)isVertical
                        andOpen:(id)filenameOrURL
             orSwitchToDocument:(ViDocument *)doc
{
	ViWindowController *windowController = [ViWindowController currentWindowController];
	BOOL newDoc = YES;

	if (filenameOrURL) {
		doc = [self openDocument:filenameOrURL andDisplay:NO allowDirectory:NO];
	} else if (doc == nil) {
		NSError *err = nil;
		doc = [self openUntitledDocumentAndDisplay:NO error:&err];
		if (err)
			[windowController message:@"%@", [err localizedDescription]];
	} else
		newDoc = NO;

	if (doc) {
		[doc addWindowController:windowController];
		[windowController addDocument:doc];

		id<ViViewController> viewController = [windowController currentView];
		ViDocumentTabController *tabController = [viewController tabController];
		ViDocumentView *newDocView = [tabController splitView:viewController
							     withView:[doc makeView]
							   vertically:isVertical];
		[windowController selectDocumentView:newDocView];

		if (!newDoc && [viewController isKindOfClass:[ViDocumentView class]]) {
			/*
			 * If we're splitting a document, position
			 * the caret in the new view appropriately.
			 */
			ViDocumentView *docView = viewController;
			[[newDocView textView] setCaret:[[docView textView] caret]];
			[[newDocView textView] scrollRangeToVisible:NSMakeRange([[docView textView] caret], 0)];
		}

		return doc;
	}

	return nil;
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

