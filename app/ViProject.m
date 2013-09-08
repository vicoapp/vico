/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "NSCollection-enumeration.h"
#import "ViProject.h"
#import "logging.h"
#import "ViFileExplorer.h"
#import "ViDocumentController.h"
#import "ViDocument.h"

@implementation ViProject

@synthesize initialURL = _initialURL;
@synthesize windowController = _windowController;

- (NSString *)title
{
	return [[_initialURL path] lastPathComponent];
}

- (ViDocumentView *)makeSplit:(NSDictionary *)splitInfo selectedDocumentURL:(NSURL *)selectedDocumentURL topLevel:(BOOL)isTopLevel
{
	ViDocumentController *documentController = [ViDocumentController sharedDocumentController];
	NSArray *documents = (NSArray *)[splitInfo objectForKey:@"documents"];
	BOOL isVertical = [((NSNumber *)[splitInfo objectForKey:@"isVertical"]) boolValue];
	// Here we map the index from the documents array to a
	// ViViewController that corresponds to the ViDocumentView in that
	// index. We only store that info for documents that are
	// actually sub-splits. This is because we fully set up this level
	// of split before going back to the subsplits and setting them up.
	NSMutableDictionary *subSplitViewControllers = [NSMutableDictionary dictionaryWithCapacity:[documents count]];

	__block ViDocumentView *documentViewToSelect = nil;
	[documents enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger documentIndex, BOOL *stop) {
		NSDictionary *documentProperties = (NSDictionary *)obj;
		if ([documentProperties objectForKey:@"url"]) { // this is a regular document
			NSURL *documentURL = [NSURL URLWithString:[documentProperties objectForKey:@"url"]];

			ViDocumentView *documentView = nil;
			if (documentIndex == [documents count] - 1) {
				id possibleDocument = [documentController openDocumentWithContentsOfURL:documentURL display:NO error:nil];
				if ([possibleDocument isKindOfClass:[ViDocument class]]) {
					ViDocument *document = (ViDocument *)possibleDocument;

					if (documentIndex != 0 && isTopLevel) {
						[_windowController createTabForDocument:document];
					}
					if (! [[_windowController window] isKeyWindow]) {
						[[_windowController window] makeKeyAndOrderFront:nil];
					}
					[_windowController displayDocument:document positioned:ViViewPositionReplace];

					documentView = [_windowController viewForDocument:document];
				}
			} else {
				documentView = [_windowController splitVertically:isVertical andOpen:documentURL];
			}

			if ([documentURL isEqual:selectedDocumentURL]) {
				documentViewToSelect = documentView;
			}

			[[documentView textView] gotoLine:[[documentProperties objectForKey:@"line"] unsignedIntegerValue]
									   column:[[documentProperties objectForKey:@"column"] unsignedIntegerValue]];
		} else { // this is information regarding an internal split
			// We'll deal with these guys again in a minute to actually unpack them;
			// for now, we're just handling this level of splits.
			if (documentIndex == [documents count] - 1) { // if this is the first split, we need a placeholder document
				ViDocument *untitledDoc = [documentController openUntitledDocumentAndDisplay:YES error:nil];
				[untitledDoc setIsTemporary:YES];

				[[untitledDoc views] anyObject]; // there should only be one of these
			} else { // these guys will just re-use an already existing document
				[_windowController splitVertically:isVertical andOpen:nil orSwitchToDocument:[_windowController currentDocument]];
			}

			[subSplitViewControllers setObject:[_windowController currentView] forKey:[NSNumber numberWithUnsignedInteger:documentIndex]];
		}
	}];

	[subSplitViewControllers enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		NSUInteger index = [((NSNumber *)key) unsignedIntegerValue];
		ViViewController *documentView = (ViViewController *)obj;

		if (documentView) {
			[_windowController selectDocumentView:documentView];
			[self makeSplit:[documents objectAtIndex:index] selectedDocumentURL:selectedDocumentURL topLevel:NO];
		}
    }];

	if ([documents count] <= 0 && isTopLevel) {
		ViDocument *untitledDoc = [documentController openUntitledDocumentAndDisplay:NO error:nil];
		[untitledDoc setIsTemporary:YES];

		[_windowController createTabForDocument:untitledDoc];
	}

	return documentViewToSelect;
}

- (BOOL)showInWindow:(ViWindowController *)aWindowController
{
	_windowController = aWindowController;
	[self addWindowController:aWindowController];
	[aWindowController setProject:self];
	[aWindowController browseURL:_initialURL];

	// Do that shiz.
	NSArray *tabs = (NSArray *)[_projectInfo objectForKey:@"tabs"];
	NSURL *selectedDocumentURL = [NSURL URLWithString:[_projectInfo objectForKey:@"selectedDocument"]];
	__block ViDocumentView *documentViewToSelect = nil;
	if (tabs && [tabs count] > 0) {
		[tabs enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger tabIndex, BOOL *stop) {
			NSDictionary *tabInfo = (NSDictionary *)obj;
			NSDictionary *rootSplit = (NSDictionary *)[tabInfo objectForKey:@"root"];

			documentViewToSelect = [self makeSplit:rootSplit selectedDocumentURL:selectedDocumentURL topLevel:YES];
		}];

		if (documentViewToSelect) {
			[aWindowController selectDocumentView:documentViewToSelect];
		}

		return YES;
	}

	return NO;
}

- (void)showOrDefaultInWindow:(ViWindowController *)aWindowController
{
	BOOL createdTabs = [self showInWindow:aWindowController];

	if (! createdTabs) {
		ViDocument *doc = [[ViDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:nil];
		[doc setIsTemporary:YES];
	}
}

- (void)makeWindowControllers
{
	ViWindowController *controller = [[ViWindowController alloc] init];
	[controller setProject:self];

	if ([controller isWindowLoaded]) {
		[self showOrDefaultInWindow:controller];
	} else {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(projectWindowDidLoad:) name:ViWindowDidLoad object:nil];

		[controller window]; // Noop fetch to initialize the window
	}
}

- (void)projectWindowDidLoad:(NSNotification *)aNotification
{
	[self showOrDefaultInWindow:[aNotification object]];

	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dealloc
{
	DEBUG_DEALLOC();
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
	_initialURL = url;

	NSMutableString *urlForPath = [NSMutableString stringWithString:[url absoluteString]];
	[urlForPath replaceOccurrencesOfString:@"_" withString:@"__" options:0 range:NSMakeRange(0, [urlForPath length])];
	[urlForPath replaceOccurrencesOfString:@"/" withString:@"_" options:0 range:NSMakeRange(0, [urlForPath length])];
	NSURL *supportDirectory =
		[[[NSFileManager defaultManager]
			  URLForDirectory:NSApplicationSupportDirectory
					 inDomain:NSUserDomainMask
			appropriateForURL:nil
					   create:YES
						error:nil] URLByAppendingPathComponent:@"Vico"];
	_dataURL = [supportDirectory URLByAppendingPathComponent:urlForPath];

	_projectInfo = [NSDictionary dictionaryWithContentsOfURL:_dataURL];
	if (! _projectInfo)
		_projectInfo = [NSDictionary dictionary];

	return YES;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	if (outError)
		*outError = [NSError errorWithDomain:@"NSURLErrorDomain" code:NSURLErrorUnsupportedURL userInfo:nil];
	return nil;
}

- (NSDictionary *)structureOfSplit:(NSSplitView *)split viewControllers:(NSArray *)viewControllers
{
	NSMutableArray *documentProperties = [NSMutableArray arrayWithCapacity:[[split subviews] count]];
	[[split subviews] eachBlock:^(id obj, BOOL *stop) {
		NSView *view = (NSView *)obj;
		__block ViDocument *document = nil;
		__block ViTextView *textView = nil;

		[viewControllers eachBlock:^(id obj, BOOL *stop) {
			ViDocumentView *controller = (ViDocumentView *)obj;

			if ([controller view] == view) {
				document = [controller document];
				textView = [controller textView];
				*stop = YES;
			}
		}];

		if (document) {
			NSString *relevantDimension;
			NSNumber *dimensionValue;
			if ([split isVertical]) {
				relevantDimension = @"width";
				dimensionValue = [NSNumber numberWithFloat:[view bounds].size.width];
			} else {
				relevantDimension = @"height";
				dimensionValue = [NSNumber numberWithFloat:[view bounds].size.height];
			}

			ViTextStorage *storage = [textView textStorage];
			NSUInteger caret = [textView caret];
			NSDictionary *viewProperties =
				@{
				  @"url": [[document fileURL] absoluteString],
				  @"line": @([storage lineNumberAtLocation:caret]),
				  @"column": @([storage columnAtLocation:caret]),
				  relevantDimension: dimensionValue
				};

			[documentProperties addObject:viewProperties];
		} else if ([view isKindOfClass:[NSSplitView class]]) {
			[documentProperties addObject:[self structureOfSplit:(NSSplitView *)view viewControllers:viewControllers]];
		}
	}];

	
	return @{
		@"documents": documentProperties,
		@"isVertical": @([split isVertical]),
	};
}

- (NSArray *)structureOfTabs:(NSTabView *)tabView
{
	NSMutableArray *tabViewProperties = [NSMutableArray arrayWithCapacity:[[tabView tabViewItems] count]];
	[[tabView tabViewItems] eachBlock:^(id obj, BOOL *stop) {
		NSTabViewItem *item = (NSTabViewItem *)obj;
		NSSplitView *split = [item view];
		ViTabController *tabController = (ViTabController *)[item identifier];
		NSArray *viewControllers = [tabController views];

		NSDictionary *tabViewProps = @{
			@"root": [self structureOfSplit:split viewControllers:viewControllers],
			@"selectedDocument": [[((ViDocument *)[[tabController selectedView] representedObject]) fileURL] absoluteString],
		};

		[tabViewProperties addObject:tabViewProps];
	}];

	return tabViewProperties;
}

- (void)close
{
	// Note: these are all open buffers, not just buffers that have views on
	// them in the open tabs/splits.
	NSSet *documentURLs = [[self.windowController documents] mapBlock:^(id obj, BOOL *stop) {
		  ViDocument *document = (ViDocument *)obj;

		  return [[document fileURL] absoluteString];
	  }];

	NSArray *tabs = [self structureOfTabs:[self.windowController tabView]];
	
	//windowController jumpList // the jump list/history
	//windowController tagStack // the list of marks
	// and also the currently focused item and caret

	_projectInfo = @{
		@"documents": [documentURLs allObjects],
		@"tabs": tabs
	};

	[_projectInfo writeToURL:_dataURL atomically:YES];

	[super close];
}

@end

