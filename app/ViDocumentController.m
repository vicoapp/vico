#import "ViDocumentController.h"
#import "ViDocument.h"
#import "ViDocumentView.h"
#import "ViWindowController.h"
#import "NSObject+SPInvocationGrabbing.h"
#import "ViError.h"
#import "TxmtURLProtocol.h"
#import "ViURLManager.h"
#import "ViEventManager.h"
#import "ViProject.h"
#include "logging.h"

@implementation ViDocumentController

- (void)callCloseAllDelegateShouldTerminate:(BOOL)flag
{
	DEBUG(@"should%s terminate", flag ? "" : " NOT");
	DEBUG(@"calling delegate %@ selector %@", closeAllDelegate, NSStringFromSelector(closeAllSelector));
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[closeAllDelegate methodSignatureForSelector:closeAllSelector]];
	[invocation setSelector:closeAllSelector];
	[invocation setArgument:&self atIndex:2];
	[invocation setArgument:&flag atIndex:3];
	[invocation setArgument:&closeAllContextInfo atIndex:4];
	[invocation invokeWithTarget:closeAllDelegate];

	closeAllSet = nil;
	closeAllDelegate = nil;
	closeAllSelector = NULL;
	closeAllContextInfo = NULL;
}

- (void)closeNextDocumentInWindow:(NSWindow *)window
{
	DEBUG(@"window %@", window);

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
	DEBUG(@"window %@ ended a sheet", window);
	[[NSNotificationCenter defaultCenter] removeObserver:self
							name:NSWindowDidEndSheetNotification
						      object:window];

	[self closeNextDocumentInWindow:window];
}

- (void)document:(NSDocument *)doc
     shouldClose:(BOOL)shouldClose
     contextInfo:(void *)contextInfo
{
	DEBUG(@"%s close document %@", shouldClose ? "SHOULD" : "Should NOT", doc);

	if (!shouldClose) {
		[self callCloseAllDelegateShouldTerminate:NO];
		return;
	}

	NSWindow *window = [[(ViDocument *)doc windowController] window];

	[doc close];

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
	DEBUG(@"%s", "closing all documents");
	closeAllDelegate = delegate;
	closeAllSelector = didCloseAllSelector;
	closeAllContextInfo = contextInfo;
	closeAllWindows = YES;
	[self closeNextDocumentInWindow:nil];
}







- (void)closeNextDocumentInSet:(NSMutableSet *)set force:(BOOL)force
{
	if ([set count] == 0) {
		[self callCloseAllDelegateShouldTerminate:YES];
		return;
	}

	ViDocument *doc = nil;
	NSWindow *window = nil;

#if 0
	/* Prefer to close a document in the current window. */
	for (doc in set) {
		if ([[[ViWindowController currentWindowController] documents] containsObject:doc]) {
			window = [[ViWindowController currentWindowController] window];
			break;
		}
	}
#endif

	if (doc == nil)
		doc = [set anyObject];
	if (window == nil)
		window = [[doc windowController] window];

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

	DEBUG(@"closing documents in set %@", set);

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

- (void)addDocument:(NSDocument *)document
{
	DEBUG(@"adding document %@", document);
	[super addDocument:document];
	if ([document fileURL]) {
		if (openDocs == nil)
			openDocs = [NSMutableDictionary dictionary];
		[openDocs setObject:document forKey:[document fileURL]];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:ViDocumentAddedNotification object:document];
	[[ViEventManager defaultManager] emit:ViEventDidAddDocument for:nil with:document, nil];
}

- (void)removeDocument:(NSDocument *)document
{
	DEBUG(@"removing document %@", document);
	[super removeDocument:document];
	if ([document fileURL])
		[openDocs removeObjectForKey:[document fileURL]];
	[[NSNotificationCenter defaultCenter] postNotificationName:ViDocumentRemovedNotification object:document];
	[[ViEventManager defaultManager] emit:ViEventDidRemoveDocument for:nil with:document, nil];
}

- (void)updateURL:(NSURL *)aURL ofDocument:(NSDocument *)document
{
	if ([document fileURL])
		[openDocs removeObjectForKey:[document fileURL]];
	if (aURL) {
		if (openDocs == nil)
			openDocs = [NSMutableDictionary dictionary];
		[openDocs setObject:document forKey:aURL];
	}
}

- (id)documentForURLQuick:(NSURL *)absoluteURL
{
	if (absoluteURL == nil)
		return nil;
	return [openDocs objectForKey:absoluteURL];
}

- (id)openDocumentWithContentsOfURL:(NSURL *)absoluteURL
                            display:(BOOL)displayDocument
                              error:(NSError **)outError
{
	absoluteURL = [absoluteURL absoluteURL];
	DEBUG(@"open %@", absoluteURL);

	ViWindowController *windowController = [ViWindowController currentWindowController];

	absoluteURL = [absoluteURL URLByResolvingSymlinksInPath];

	id doc = [self documentForURL:absoluteURL];
	if (doc) {
		if (displayDocument) {
			if ([doc isKindOfClass:[ViDocument class]]) {
				if ([doc windowController] == windowController)
					[[doc windowController] selectDocument:doc];
				else
					[windowController addNewTab:doc];
			} else if ([doc isKindOfClass:[ViProject class]]) {
				[[[doc windowController] window] makeKeyAndOrderFront:nil];
			}
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
	if (doc && !displayDocument && ![doc isKindOfClass:[ViProject class]]) {
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
		ViWindowController *winController = [ViWindowController currentWindowController];
		if (winController)
			relURL = [winController baseURL];
		else
			relURL = [NSURL fileURLWithPath:@"/"];
	}

	NSString *escapedFilename = [filename stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSURL *url = [NSURL URLWithString:escapedFilename relativeToURL:relURL];
	NSURL *normalizedURL = [[ViURLManager defaultManager] normalizeURL:url];
	DEBUG(@"normalized %@ -> %@", url, normalizedURL);
	NSURL *resolvedURL = [normalizedURL URLByResolvingSymlinksInPath];
	DEBUG(@"resolved %@ -> %@", normalizedURL, resolvedURL);
	return resolvedURL;
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

	return @"Document";
}

@end

