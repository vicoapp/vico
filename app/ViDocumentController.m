#define FORCE_DEBUG
#import "ViDocumentController.h"
#import "ViDocumentTabController.h"
#import "ViDocument.h"
#import "ViDocumentView.h"
#import "ViWindowController.h"
#import "ExEnvironment.h"
#import "NSObject+SPInvocationGrabbing.h"
#import "ViError.h"
#import "TxmtURLProtocol.h"
#import "ViURLManager.h"
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

- (BOOL)supportedURLScheme:(NSURL *)url
{
	if ([[ViURLManager defaultManager] respondsToURL:url] ||
	    [[url scheme] isEqualToString:@"vico"] ||
	    [[url scheme] isEqualToString:@"txmt"])
		return YES;
	return NO;
}

- (id)openDocumentWithContentsOfURL:(NSURL *)absoluteURL
                            display:(BOOL)displayDocument
                              error:(NSError **)outError
{
	absoluteURL = [absoluteURL absoluteURL];
	DEBUG(@"open %@", absoluteURL);

	ViWindowController *windowController = [ViWindowController currentWindowController];

	id doc = [self documentForURL:absoluteURL];
	if (doc) {
		if (displayDocument) {
			if ([doc windowController] == windowController)
				[[doc windowController] selectDocument:doc];
			else
				[windowController createTabForDocument:doc];
		}
		return doc;
	}

	NSNumber *lineNumber = nil;
	NSURL *url = [TxmtURLProtocol parseURL:absoluteURL intoLineNumber:&lineNumber];
	if (url == nil) {
		if (outError)
			*outError = [ViError errorWithFormat:@"invalid URL"];
		return nil;
	}

	if (![self supportedURLScheme:url]) {
		if (outError)
			*outError = [ViError errorWithFormat:@"Unsupported URL scheme '%@'",
			    [url scheme]];
		return nil;
	}

	doc = [super openDocumentWithContentsOfURL:url
					   display:displayDocument
					     error:outError];
	if (doc && !displayDocument) {
		[doc addWindowController:windowController];
		[windowController addDocument:doc];
	}

	return doc;
}

- (NSURL *)normalizePath:(NSString *)filename
              relativeTo:(NSURL *)relURL
                   error:(NSError **)outError
{
	if (filename == nil)
		return nil;

	if (relURL ==  nil) {
		ExEnvironment *env = [[ViWindowController currentWindowController] environment];
		if (env)
			relURL = [env baseURL];
		else
			relURL = [NSURL fileURLWithPath:@"/"];
	}

	NSString *escapedFilename = [filename stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSURL *url = [NSURL URLWithString:escapedFilename];
	NSString *path;
	if (url == nil || [url scheme] == nil)
		path = escapedFilename;
	else {
		relURL = url;
		path = [url path];
	}

	if ([path hasPrefix:@"~"] || [path hasPrefix:@"/~"]) {
		if (relURL == nil || [relURL isFileURL])
			path = [path stringByExpandingTildeInPath];
#if 0 // FIXME!
		else {
			SFTPConnection *conn = [[SFTPConnectionPool sharedPool]
			    connectionWithURL:relURL error:outError];
			if (conn == nil)
				return nil;
			NSRange r = NSMakeRange(0, 1);
			if ([path hasPrefix:@"/~"])
				r.length = 2;
			path = [path stringByReplacingCharactersInRange:r
							     withString:[conn home]];
		}
#endif
	}

	url = [NSURL URLWithString:path relativeToURL:relURL];

	return [url absoluteURL];
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
	DEBUG(@"determining type for %@", url);

	if ([[url absoluteString] hasSuffix:@"/"])
		return @"Project";

#if 0
	BOOL isDirectory;
	if ([url isFileURL]) {
		if ([[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDirectory] && isDirectory)
			return @"Project";
	} else if ([[url scheme] isEqualToString:@"sftp"]) {
		SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:url error:outError];
		if ([conn fileExistsAtPath:[url path] isDirectory:&isDirectory error:outError] && isDirectory)
			return @"Project";
	}
#endif

	return @"Document";
}

@end

