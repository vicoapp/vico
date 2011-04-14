#import "ViDocumentController.h"
#import "ViDocumentTabController.h"
#import "ViDocument.h"
#import "ViDocumentView.h"
#import "ViWindowController.h"
#import "ExEnvironment.h"
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

- (BOOL)fileAppearsBinaryAtURL:(NSURL *)absoluteURL
{
	NSData *chunk = nil;

	if ([absoluteURL isFileURL]) {
		NSFileHandle *handle = [NSFileHandle fileHandleForReadingFromURL:absoluteURL
									   error:nil];
		chunk = [handle readDataOfLength:1024];
		[handle closeFile];
	}
	/* SFTP URLs not yet handled */

	if (chunk == nil)
		return NO;

	const void *buf = [chunk bytes];
	NSUInteger length = [chunk length];
	if (buf == NULL)
		return NO;

	if (memchr(buf, 0, length) != NULL)
		return YES;
	return NO;
}

- (id)openDocumentWithContentsOfURL:(NSURL *)absoluteURL
                            display:(BOOL)displayDocument
                              error:(NSError **)outError
{
	id doc = [self documentForURL:absoluteURL];
	if (doc)
		return doc;

	if ([self fileAppearsBinaryAtURL:absoluteURL]) {
		NSAlert *alert = [[NSAlert alloc] init];
		[alert setMessageText:[NSString stringWithFormat:@"%@ appears to be a binary file",
			[absoluteURL lastPathComponent]]];
		[alert addButtonWithTitle:@"Open"];
		[alert addButtonWithTitle:@"Cancel"];
		[alert setInformativeText:@"Are you sure you want to continue opening the file?"];
		NSUInteger ret = [alert runModal];
		if (ret == NSAlertSecondButtonReturn)
			return nil;
	}

	return [super openDocumentWithContentsOfURL:absoluteURL
					    display:displayDocument
					      error:outError];
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
	}

	url = [NSURL URLWithString:path relativeToURL:relURL];

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

