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

#import "ViWindowController.h"
#import "PSMTabBarControl.h"
#import "ViDocument.h"
#import "ViDocumentView.h"
#import "ViProject.h"
#import "ViFileExplorer.h"
#import "ViJumpList.h"
#import "ViThemeStore.h"
#import "ViBundleStore.h"
#import "ViDocumentController.h"
#import "ViPreferencesController.h"
#import "ViAppController.h"
#import "ViTextStorage.h"
#import "NSObject+SPInvocationGrabbing.h"
#import "ViLayoutManager.h"
#import "ExTextField.h"
#import "ViEventManager.h"
#import "NSURL-additions.h"
#import "ExCommand.h"
#import "ViError.h"
#import "ViBgView.h"
#import "ViMark.h"
#import "NSWindow-additions.h"

static NSMutableArray			*__windowControllers = nil;
static __weak ViWindowController	*__currentWindowController = nil; // XXX: not retained!

@interface ViWindowController ()
- (void)updateJumplistNavigator;
- (void)didSelectDocument:(ViDocument *)document;
- (void)didSelectViewController:(ViViewController *)viewController;
- (void)closeDocumentView:(ViViewController *)viewController
	 canCloseDocument:(BOOL)canCloseDocument
	   canCloseWindow:(BOOL)canCloseWindow;
- (void)documentController:(NSDocumentController *)docController
	       didCloseAll:(BOOL)didCloseAll
	     tabController:(void *)tabController;
- (void)unlistDocument:(ViDocument *)document;
- (void)willChangeCurrentView;
- (void)didChangeCurrentView;
- (void)closeTabController:(ViTabController *)tabController;
- (void)closeOrUnlistDocument:(ViDocument *)document unlessVisible:(BOOL)unlessVisible;
@end


#pragma mark -
@implementation ViWindowController

@synthesize documents = _documents;
@synthesize project = _project;
@synthesize explorer = explorer;
@synthesize jumpList = _jumpList;
@synthesize jumping = _jumping;
@synthesize alternateMark = _alternateMark;
@synthesize alternateMarkCandidate = _alternateMarkCandidate;
@synthesize baseURL = _baseURL;
@synthesize symbolController;
@synthesize parser = _parser;

+ (ViWindowController *)currentWindowController
{
	// if (__currentWindowController == nil) {
	// 	ViWindowController *windowController = [[[ViWindowController alloc] init] autorelease];
	// 	[windowController window]; // trigger immediate NIB loading
	// }
	return __currentWindowController;
}

- (id)init
{
	if ((self = [super initWithWindowNibName:@"ViDocumentWindow"]) != nil) {
		_isLoaded = NO;
		if (__windowControllers == nil)
			__windowControllers = [[NSMutableArray alloc] init];
		[__windowControllers addObject:self];
		__currentWindowController = self;
		_documents = [[NSMutableSet alloc] init];
		_jumpList = [[ViJumpList alloc] init];
		[_jumpList setDelegate:self];
		_parser = [[ViParser alloc] initWithDefaultMap:[ViMap normalMap]];
		[self setBaseURL:[NSURL fileURLWithPath:NSHomeDirectory()]];

        [[NSUserDefaults standardUserDefaults] addObserver:self
                                                forKeyPath:@"includedevelopmenu"
                                                   options:0
                                                   context:NULL];
	}

	DEBUG_INIT();
	return self;
}

DEBUG_FINALIZE();

- (void)dealloc
{
	DEBUG_DEALLOC();

	[[ViEventManager defaultManager] clearFor:self];

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"undostyle"];
	[[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"includedevelopmenu"];

	NSArray *items = [[openFilesButton menu] itemArray];
	if ([items count] > 0) {
		MEMDEBUG(@"Got remaining items in open files menu: %@", items);
	}

	// INFO(@"closing window %@, got %lu document left: %@", self, [_documents count], _documents);
	// for (ViDocument *doc in _documents)
	// 	[doc removeObserver:symbolController forKeyPath:@"symbols"];

	[_checkURLDeferred setDelegate:nil];
	[_checkURLDeferred cancel];
	[_checkURLDeferred release];

	[_baseURL release];
	[_viFieldEditor release];
	[_viFieldEditorStorage release];
	[_tagStack release];
	[_tagsDatabase release];
	[_documents release];
	[_parser release];
	[_project release];
	[_jumpList setDelegate:nil];
	[_jumpList release];
	[_currentView release];
	[_modifiedSet release];

	// ?
	[_initialDocument release];
	[_initialViewController release];

	[_alternateMark release];
	[_alternateMarkCandidate release];

	/*
	 * Top-level nib objects released by super NSWindowController
	 */

	[super dealloc];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViWindowController %p: %@>", self, _baseURL];
}

- (ViMarkList *)tagStack
{
	return [_tagStack list];
}

- (ViTagsDatabase *)tagsDatabase
{
	if (![[_tagsDatabase baseURL] isEqualToURL:_baseURL]) {
		[_tagsDatabase release];
		_tagsDatabase = nil;
	}

	if (_tagsDatabase == nil)
		_tagsDatabase = [[ViTagsDatabase alloc] initWithBaseURL:_baseURL];

	return _tagsDatabase;
}

- (void)getMoreBundles:(id)sender
{
	[[ViPreferencesController sharedPreferences] performSelector:@selector(showItem:)
							  withObject:@"Bundles"
							  afterDelay:0.01];
}

- (void)windowDidResize:(NSNotification *)notification
{
	[[self window] saveFrameUsingName:@"MainDocumentWindow"];
}

- (void)tearDownBundleMenu:(NSNotification *)notification
{
	NSMenu *menu = [notification object];

	/*
	 * Must remove the bundle menu items, otherwise the key equivalents
	 * remain active and interfere with the handling in textView.keyDown:.
	 */
	[menu removeAllItems];

	[[NSNotificationCenter defaultCenter] removeObserver:self
							name:NSMenuDidEndTrackingNotification
						      object:menu];
}

- (void)setupBundleMenu:(NSNotification *)notification
{
	ViViewController *viewController = [self currentView];
	if (![viewController isKindOfClass:[ViDocumentView class]])
		return;
	ViDocumentView *docView = (ViDocumentView *)viewController;
	ViTextView *textView = [docView textView];

	NSEvent *ev = [textView popUpContextEvent];
	NSMenu *menu = [textView menuForEvent:ev];
	/* Insert a dummy item at index 0 as the NSPopUpButton title. */
	[menu insertItemWithTitle:@"Action menu" action:NULL keyEquivalent:@"" atIndex:0];
	[menu update];
	[bundleButton setMenu:menu];

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(tearDownBundleMenu:)
						     name:NSMenuDidEndTrackingNotification
						   object:menu];
}

- (void)windowDidLoad
{
	_tagStack = [[[ViMarkManager sharedManager] stackWithName:[NSString stringWithFormat:@"Tag Stack for window %p", self]] retain];
	[_tagStack setMaxLists:1];

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(firstResponderChanged:)
						     name:ViFirstResponderChangedNotification
						   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(caretChanged:)
						     name:ViCaretChangedNotification
						   object:nil];

	[[[self window] toolbar] setShowsBaselineSeparator:NO];
	[bookmarksButtonCell setImage:[NSImage imageNamed:@"bookmark"]];

	[bundleButtonCell setImage:[NSImage imageNamed:@"actionmenu"]];
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(setupBundleMenu:)
						     name:NSPopUpButtonWillPopUpNotification
						   object:bundleButton];

	[[tabBar addTabButton] setTarget:self];
	[[tabBar addTabButton] setAction:@selector(addNewDocumentTab:)];
	[tabBar setStyleNamed:@"Metal"];
	[tabBar setCanCloseOnlyTab:NO];
	[tabBar setHideForSingleTab:[[NSUserDefaults standardUserDefaults] boolForKey:@"hidetab"]];
	// FIXME: add KVC observer for the 'hidetab' option
	[tabBar setPartnerView:splitView];
	[tabBar setShowAddTabButton:YES];
	[tabBar setAllowsDragBetweenWindows:NO]; // XXX: Must update for this to work without NSTabview

	[[self window] setOpaque:NO];
	[[self window] setDelegate:self];
	[[self window] setFrameUsingName:@"MainDocumentWindow"];

	[splitView addSubview:explorerView positioned:NSWindowBelow relativeTo:mainView];
	[splitView addSubview:symbolsView];

	_isLoaded = YES;
	if (_initialDocument) {
		[self addNewTab:_initialDocument];
		[_initialDocument release];
		_initialDocument = nil;
	}
	if (_initialViewController) {
		[self createTabWithViewController:_initialViewController];
		[_initialViewController release];
		_initialViewController = nil;
	}

	[[self window] setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];
	[[self window] makeKeyAndOrderFront:self];

	NSRect frame = [splitView frame];
	[splitView setPosition:0 ofDividerAtIndex:0]; // Explorer not shown on launch
	[splitView setPosition:NSWidth(frame) ofDividerAtIndex:1]; // Symbol list not shown on launch

	if ([self project] != nil) {
		[self setBaseURL:[[self project] initialURL]];
		[explorer openExplorerTemporarily:NO];
		/* This makes repeated open requests for the same URL always open a new window.
		 * With this commented, the "project" is already opened, and no new window will be created.
		 */
		[[self project] close];
		_project = nil;
	}

	[self updateJumplistNavigator];

	[_parser setNviStyleUndo:[[[NSUserDefaults standardUserDefaults] stringForKey:@"undostyle"] isEqualToString:@"nvi"]];
	[[NSUserDefaults standardUserDefaults] addObserver:self
						forKeyPath:@"undostyle"
						   options:NSKeyValueObservingOptionNew
						   context:NULL];

	// Set up default status bar.
	NuBlock *statusSetupBlock = [[NSApp delegate] statusSetupBlock];
	if (statusSetupBlock) {
		NuCell *argument = [[NSArray arrayWithObject:messageView] list];

		@try {
			[statusSetupBlock evalWithArguments:argument
										context:[statusSetupBlock context]];
		}
		@catch (NSException *exception) {
			INFO(@"got exception %@ while evaluating expression:\n%@", [exception name], [exception reason]);
			INFO(@"context was: %@", [statusSetupBlock context]);
			[self message:[NSString stringWithFormat:@"Got exception %@: %@", [exception name], [exception reason]]];
		}
	} else {
		ViStatusNotificationLabel *caretLabel =
			[ViStatusNotificationLabel statusLabelForNotification:ViCaretChangedNotification
												  withTransformer:^(ViStatusView *statusView, NSNotification *notification) {
				ViTextView *textView = (ViTextView *)[notification object];

				// If this is the ex box (which has no superview) or this is not
				// for the current window, we bail on out.
				if ([statusView window] != [textView window])
					return (id)nil;

				return [NSString stringWithFormat:@"%lu,%lu",
					(unsigned long)[textView currentLine],
					(unsigned long)[textView currentColumn]];
		  }];
		ViStatusNotificationLabel *modeLabel =
			[ViStatusNotificationLabel statusLabelForNotification:ViModeChangedNotification
												withTransformer:^(ViStatusView *statusView, NSNotification *notification) {
				ViTextView *textView = (ViTextView *)[notification object];
				ViDocument *document = textView.document;

				// If this is the ex box (which has no superview) or this is not
				// for the current window, we bail on out.
				if (! [textView superview] || [statusView window] != [textView window])
					return (id)nil;

				const char *modestr = "";
				if (document.busy) {
					modestr = "--BUSY--";
				} else if (textView.mode == ViInsertMode) {
					if (document.snippet)
						modestr = "--SNIPPET--";
					else
						modestr = "--INSERT--";
				} else if (textView.mode == ViVisualMode) {
					if (textView.visual_line_mode)
						modestr = "--VISUAL LINE--";
					else
						modestr = "--VISUAL--";
				}

				return [NSString stringWithFormat:@"    %s", modestr];
			}];

		[messageView setStatusComponents:[NSArray arrayWithObjects:caretLabel, modeLabel, nil]];
	}
}

- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)anObject
{
	if ([anObject isKindOfClass:[ExTextField class]]) {
		if (_viFieldEditor == nil) {
			_viFieldEditorStorage = [[ViTextStorage alloc] init];
			_viFieldEditor = [[ViTextView makeFieldEditorWithTextStorage:_viFieldEditorStorage] retain];
		}
		return _viFieldEditor;
	}
	return nil;
}

- (NSApplicationPresentationOptions)window:(NSWindow *)window
      willUseFullScreenPresentationOptions:(NSApplicationPresentationOptions)proposedOptions
{
	return proposedOptions | NSApplicationPresentationAutoHideToolbar;
}

- (void)windowWillEnterFullScreen:(NSNotification *)notification
{
	[[ViEventManager defaultManager] emit:ViEventWillEnterFullScreen for:self with:self, nil];
}

- (void)windowDidEnterFullScreen:(NSNotification *)notification
{
	[[ViEventManager defaultManager] emit:ViEventDidEnterFullScreen for:self with:self, nil];
}

- (void)windowWillExitFullScreen:(NSNotification *)notification
{
	[[ViEventManager defaultManager] emit:ViEventWillExitFullScreen for:self with:self, nil];
}

- (void)windowDidExitFullScreen:(NSNotification *)notification
{
	[[ViEventManager defaultManager] emit:ViEventDidExitFullScreen for:self with:self, nil];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
	NSURL *url = [[self document] fileURL];
	if (url == nil)
		return displayName;
	return [NSString stringWithFormat:@"%@  (%@)",
		displayName, [[url URLByDeletingLastPathComponent] displayString]];
}

- (IBAction)addNewDocumentTab:(id)sender
{
	[[NSDocumentController sharedDocumentController] newDocument:self];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
	if ([keyPath isEqualToString:@"undostyle"]) {
		NSString *newStyle = [change objectForKey:NSKeyValueChangeNewKey];
		[_parser setNviStyleUndo:[newStyle isEqualToString:@"nvi"]];
	} else if ([keyPath isEqualToString:@"includedevelopmenu"]) {
        BOOL showMenu = [[NSUserDefaults standardUserDefaults] boolForKey:@"includedevelopmenu"];

        [[ViDocumentController sharedDocumentController] showDevelopMenu:showMenu];
	}
}

- (void)addDocument:(ViDocument *)document
{
	if ([_documents containsObject:document])
		return;

	if ([document isKindOfClass:[ViProject class]])
		return;

	NSArray *items = [[openFilesButton menu] itemArray];
	NSInteger ndx;
	for (ndx = 0; ndx < [items count]; ndx++)
		if ([[document displayName] compare:[[items objectAtIndex:ndx] title]
					    options:NSCaseInsensitiveSearch] == NSOrderedAscending)
			break;
	NSMenuItem *item = [[openFilesButton menu] insertItemWithTitle:[document displayName]
								action:@selector(switchToDocumentAction:)
							 keyEquivalent:@""
							       atIndex:ndx];
	[item setRepresentedObject:document];
	[item bind:@"title" toObject:document withKeyPath:@"title" options:nil];

	[_documents addObject:document];

	/* Update symbol table. */
	[symbolController filterSymbols];
	[document addObserver:symbolController forKeyPath:@"symbols" options:0 context:NULL];
}

/* Create a new document tab.
 */
- (ViTabController *)createTabWithViewController:(ViViewController *)viewController
{
	if (!_isLoaded) {
		/* Defer until NIB is loaded. */
		_initialViewController = [viewController retain];
		return nil;
	}

	ViTabController *tabController = [[ViTabController alloc] initWithViewController:viewController window:[self window]];

	if ([viewController isKindOfClass:[ViDocumentView class]]) {
		/* Make sure the document is registered in this window. */
		[self addDocument:[(ViDocumentView *)viewController document]];
	}

	NSTabViewItem *tabItem = [(NSTabViewItem *)[NSTabViewItem alloc] initWithIdentifier:tabController];
	[tabItem bind:@"label" toObject:tabController withKeyPath:@"selectedView.title" options:nil];
	[tabItem setView:[tabController view]];
	[tabView addTabViewItem:tabItem];
	[tabItem release];
	[tabView selectTabViewItem:tabItem];
	[self focusEditor];
	return [tabController autorelease];
}

- (ViDocumentView *)createTabForDocument:(ViDocument *)document
{
	ViDocumentView *docView = [document makeViewWithParser:_parser];
	[self createTabWithViewController:docView];
	return docView;
}

/* Called by a new ViDocument in its makeWindowControllers method.
 */
- (void)addNewTab:(ViDocument *)document
{
	if (!_isLoaded) {
		/* Defer until NIB is loaded. */
		_initialDocument = [document retain];
		return;
	}

	[self displayDocument:document positioned:ViViewPositionDefault];
}

- (void)focusEditorDelayed
{
	if ([self currentView])
		[[self window] makeFirstResponder:[[self currentView] innerView]];
}

- (void)focusEditor
{
	[[self nextRunloop] focusEditorDelayed];
}

- (void)windowDidBecomeMain:(NSNotification *)aNotification
{
	__currentWindowController = self;
	[self checkDocumentsChanged];
}

- (ViDocument *)currentDocument
{
	return [[self currentDocumentView] document];
}

- (void)caretChanged:(NSNotification *)notification
{
	ViTextView *textView = [notification object];
	if (textView == [[self currentView] innerView])
		[symbolController updateSelectedSymbolForLocation:[textView caret]];
}

- (void)showMessage:(NSString *)string
{
	[messageView setMessage:string];
}

- (void)message:(NSString *)fmt arguments:(va_list)ap
{
	[messageView setMessage:[[[NSString alloc] initWithFormat:fmt arguments:ap] autorelease]];
}

- (void)message:(NSString *)fmt, ...
{
	va_list ap;
	va_start(ap, fmt);
	[self message:fmt arguments:ap];
	va_end(ap);
}

- (NSDictionary *)environment
{
	NSMutableDictionary *env = [NSMutableDictionary dictionary];
	[ViBundle setupEnvironment:env forTextView:nil window:[self window] bundle:nil];
	return env;
}

/* Reveal current document in explorer. */
- (IBAction)revealCurrentDocument:(id)sender
{
	NSURL *url = [[self currentDocument] fileURL];
	if (url == nil)
		MESSAGE(@"Can't reveal untitled documents");
	else if ([explorer selectItemWithURL:url])
		[explorer focusExplorer:nil];
	else
		MESSAGE(@"%@ not found in explorer", [url lastPathComponent]);
}

#pragma mark -

- (void)browseURL:(NSURL *)url
{
	[explorer browseURL:url];
}

- (void)setBaseURL:(NSURL *)url
{
	if (![[url absoluteString] hasSuffix:@"/"])
		url = [NSURL URLWithString:[[url lastPathComponent] stringByAppendingString:@"/"]
			     relativeToURL:url];

	[_baseURL release];
	_baseURL = [[url absoluteURL] retain];
	[self synchronizeWindowTitleWithDocumentName];
}

- (void)deferred:(id<ViDeferred>)deferred status:(NSString *)statusMessage
{
	[self message:@"%@", statusMessage];
}

- (void)checkBaseURL:(NSURL *)url onCompletion:(void (^)(NSURL *url, NSError *error))aBlock
{
	if (_checkURLDeferred) {
		[_checkURLDeferred setDelegate:nil];
		[_checkURLDeferred cancel];
		[_checkURLDeferred release];
	}

	void (^blockCopy)(NSURL *, NSError *) = [[aBlock copy] autorelease];
	_checkURLDeferred = [[ViURLManager defaultManager] fileExistsAtURL:url
							      onCompletion:^(NSURL *normalizedURL, BOOL isDirectory, NSError *error) {
		if (error)
			blockCopy(nil, [ViError errorWithFormat:@"%@: %@", [url path], [error localizedDescription]]);
		else if (normalizedURL == nil)
			blockCopy(nil, [ViError errorWithFormat:@"%@: no such file or directory", [url path]]);
		else if (!isDirectory)
			blockCopy(nil, [ViError errorWithFormat:@"%@: not a directory", [normalizedURL path]]);
		else
			blockCopy(normalizedURL, nil);
	}];
	[_checkURLDeferred retain]; // must retain so deferred doesn't call a dealloced delegate. Cancel in dealloc.
	[_checkURLDeferred setDelegate:self];
}

- (NSString *)displayBaseURL
{
	return [_baseURL displayString];
}

#pragma mark -
#pragma mark Notification of changes on disk

- (void)alertModifiedDocuments
{
	NSUInteger nmodified = [_modifiedSet count];
	if (nmodified == 0) {
		return;
	}

	// Choose the most appropriate document from the set of modified documents.
	// Try to minimize the number of document switches.

	ViDocument *document = nil;

	/* Check if the current view contains a modified document. */
	ViDocumentView *docView = [self currentDocumentView];
	if (docView && [_modifiedSet containsObject:[docView document]]) {
		document = [docView document];
	}

	/* Check if current tab has a view of a modified document. */
	if (document == nil) {
		ViTabController *tabController = [self selectedTabController];
		for (ViViewController *viewController in [tabController views]) {
			if ([viewController isKindOfClass:[ViDocumentView class]] &&
			    [_modifiedSet containsObject:[(ViDocumentView *)viewController document]]) {
				document = [(ViDocumentView *)viewController document];
				break;
			}
		}
	}

	if (document == nil) {
		document = [_modifiedSet anyObject];
	}

	[self displayDocument:document positioned:ViViewPositionDefault];

	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	if (nmodified == 1) {
		[alert setMessageText:[NSString stringWithFormat:@"The document \"%@\", has been changed by another application since you opened or saved it.",
			[[document fileURL] lastPathComponent]]];
	} else {
		[alert setMessageText:[NSString stringWithFormat:@"The document \"%@\", and %lu other documents, has been changed by another application since you opened or saved it.",
			[[document fileURL] lastPathComponent], nmodified - 1]];
	}
	[alert setInformativeText:@"Do you want to keep the open version or revert to the document on disk?"];
	[alert addButtonWithTitle:[NSString stringWithFormat:@"Revert %@", [[document fileURL] lastPathComponent]]];
	if (nmodified > 1) {
		[alert addButtonWithTitle:@"Revert all"];
	}
	[alert addButtonWithTitle:[NSString stringWithFormat:@"Keep %@", [[document fileURL] lastPathComponent]]];
	if (nmodified > 1) {
		[alert addButtonWithTitle:@"Keep all"];
	}
	[alert beginSheetModalForWindow:[self window]
			  modalDelegate:self
			 didEndSelector:@selector(documentChangedAlertDidEnd:returnCode:contextInfo:)
			    contextInfo:document];
}

- (void)revertAllModified
{
	ViDocument *document;
	while ((document = [_modifiedSet anyObject]) != nil) {
		NSError *error = nil;
		[_modifiedSet removeObject:document];
		[document revertToContentsOfURL:[document fileURL]
					 ofType:[document fileType]
					  error:&error];
		if (error) {
			NSAlert *revertAlert = [NSAlert alertWithError:error];
			[revertAlert beginSheetModalForWindow:[self window]
						modalDelegate:self
					       didEndSelector:@selector(revertFailedAlertDidEnd:returnCode:contextInfo:)
						  contextInfo:(void *)(intptr_t)1];
			[document updateChangeCount:NSChangeReadOtherContents];
			break;
		}
	}
}

- (void)revertFailedAlertDidEnd:(NSAlert *)alert
		     returnCode:(NSInteger)returnCode
		    contextInfo:(void *)contextInfo
{
	[[alert window] orderOut:self];
	intptr_t state = (intptr_t)contextInfo;
	if (state == 0) { // alert next modified document
		[self alertModifiedDocuments];
	} else if (state == 1) { // revert all modified documents
		[self revertAllModified];
	}
}

- (void)documentsDeletedAlertDidEnd:(NSAlert *)alert
			 returnCode:(NSInteger)returnCode
			contextInfo:(void *)contextInfo
{
	[[alert window] orderOut:self];
	[self alertModifiedDocuments];
}

- (void)documentChangedAlertDidEnd:(NSAlert *)alert
			returnCode:(NSInteger)returnCode
		       contextInfo:(void *)contextInfo
{
	ViDocument *document = contextInfo;

	// 1. revert document
	// 2. revert all documents
	// 3. keep document
	// 4. keep all documents

	// - or -

	// 1. revert document
	// 2. keep document

	[[alert window] orderOut:self];

	NSUInteger nbuttons = [[alert buttons] count];

	if (returnCode == NSAlertFirstButtonReturn) {
		NSError *error = nil;
		[_modifiedSet removeObject:document];
		[document revertToContentsOfURL:[document fileURL]
					 ofType:[document fileType]
					  error:&error];
		if (error) {
			NSAlert *revertAlert = [NSAlert alertWithError:error];
			[revertAlert beginSheetModalForWindow:[self window]
					        modalDelegate:self
					       didEndSelector:@selector(revertFailedAlertDidEnd:returnCode:contextInfo:)
						  contextInfo:(void *)(intptr_t)0];
			[document updateChangeCount:NSChangeReadOtherContents];
		} else {
			[self alertModifiedDocuments];
		}
	} else if (returnCode == NSAlertSecondButtonReturn && nbuttons == 4) {
		[self revertAllModified];
	} else if ((returnCode == NSAlertThirdButtonReturn && nbuttons == 4) ||
	           (returnCode == NSAlertSecondButtonReturn && nbuttons == 2)) {
		[_modifiedSet removeObject:document];
		document.isTemporary = YES;
		[self alertModifiedDocuments];
	} else if (returnCode == NSAlertThirdButtonReturn + 1 && nbuttons == 4) {
		for (document in _modifiedSet)
			document.isTemporary = YES;
		[_modifiedSet release];
		_modifiedSet = nil;
	}
}

- (void)checkDocumentsChanged
{
	BOOL askAllModified = [[NSUserDefaults standardUserDefaults] boolForKey:@"alwaysAskModifiedDocument"];
	NSMutableSet *deletedSet = [NSMutableSet set];
	[_modifiedSet release];
	_modifiedSet = [[NSMutableSet alloc] init];
	for (ViDocument *document in _documents) {
		if (document.isTemporary || ![[document fileURL] isFileURL]) {
			continue;
		}

		NSError *error = nil;
		NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[[document fileURL] path] error:&error];
		if (error) {
			[document updateChangeCount:NSChangeReadOtherContents];
			document.isTemporary = YES;
			if ([error isFileNotFoundError]) {
				[deletedSet addObject:document];
			} else {
				INFO(@"failed to stat %@: %@", [[document fileURL] path], [error localizedDescription]);
			}
		} else {
			NSDate *modificationDate = [attributes fileModificationDate];
			if ([[document fileModificationDate] compare:modificationDate] == NSOrderedAscending) {
				if ([document isDocumentEdited] || askAllModified) {
					[document updateChangeCount:NSChangeReadOtherContents];
					[_modifiedSet addObject:document];
				} else {
					[document revertToContentsOfURL:[document fileURL]
								 ofType:[document fileType]
								  error:&error];
					if (error) {
						[[NSAlert alertWithError:error] runModal];
						[document updateChangeCount:NSChangeReadOtherContents];
					}
				}
			}
		}
	}

	NSUInteger ndeleted = [deletedSet count];
	if (ndeleted > 0) {
		NSAlert *alert = [[NSAlert alloc] init];
		const char *pluralS = (ndeleted == 1 ? "" : "s");
		if (ndeleted == 1) {
			[alert setMessageText:[NSString stringWithFormat:@"The document \"%@\" was deleted from disk by another application.",
				[[[deletedSet anyObject] fileURL] lastPathComponent]]];
		} else {
			[alert setMessageText:[NSString stringWithFormat:@"%lu document%s was deleted from disk by another application.",
				ndeleted, pluralS]];
		}
		[alert setInformativeText:[NSString stringWithFormat:@"The document%s remain%s open.", pluralS, ndeleted == 1 ? "s" : ""]];
		[alert beginSheetModalForWindow:[self window]
				  modalDelegate:self
				 didEndSelector:@selector(documentsDeletedAlertDidEnd:returnCode:contextInfo:)
				    contextInfo:nil];
	} else {
		[self alertModifiedDocuments];
	}
}

#pragma mark -
#pragma mark Document closing

- (void)closeAllViews
{
	DEBUG(@"close all views in window controller %@", self);
	DEBUG(@"documents = %@", _documents);

	/* Close down all documents. */
	ViDocument *doc;
	while ((doc = [_documents anyObject]) != nil) {
		[self closeOrUnlistDocument:doc unlessVisible:NO];
	}

	/* Close down all tabs. */
	while ([tabView numberOfTabViewItems] > 0) {
		NSTabViewItem *item = [tabView tabViewItemAtIndex:0];
		ViTabController *tabController = [item identifier];
		/* Close any views left in this tab. Do not ask for confirmation. */
		while ([[tabController views] count] > 0) {
			[tabController closeView:[[tabController views] objectAtIndex:0]];
		}
		[self closeTabController:tabController];
	}
}

- (void)documentController:(NSDocumentController *)docController
               didCloseAll:(BOOL)didCloseAll
               contextInfo:(void *)contextInfo
{
	DEBUG(@"force closing all views: %s", didCloseAll ? "YES" : "NO");
	if (!didCloseAll) {
		return;
	}

	[self closeAllViews];
	[[self window] close];
}

/* Check if a document is open in another window. */
- (BOOL)documentOpenElsewhere:(ViDocument *)document
{
	for (NSWindow *window in [NSApp windows]) {
		ViWindowController *wincon = [window windowController];
		if (wincon == self || ![wincon isKindOfClass:[ViWindowController class]]) {
			continue;
		}
		if ([[wincon documents] containsObject:document]) {
			return YES;
		}
	}

	return NO;
}

- (BOOL)windowShouldClose:(id)window
{
	DEBUG(@"documents = %@", _documents);

	if ([_documents count] == 0)
		return YES;

	NSMutableSet *set = [NSMutableSet set];
	for (ViDocument *doc in _documents) {
		if ([set containsObject:doc]) {
			continue;
		}
		if (![doc isDocumentEdited]) {
			continue;
		}
		if (![self documentOpenElsewhere:doc]) {
			[set addObject:doc];
		}
	}

	[[ViDocumentController sharedDocumentController] closeAllDocumentsInSet:set
								   withDelegate:self
							    didCloseAllSelector:@selector(documentController:didCloseAll:contextInfo:)
								    contextInfo:window];
	return NO;
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	if (_isClosing) {
		DEBUG(@"%s", "avoiding recursive window closing");
		return;
	}
	_isClosing = YES;
	if (__currentWindowController == self) {
		__currentWindowController = nil;
	}
	DEBUG(@"will close %@", self);
	[[self project] close];
	MEMDEBUG(@"remaining window controllers: %@", __windowControllers);
	MEMDEBUG(@"remaining tabs: %@", [tabBar representedTabViewItems]);

	[self closeAllViews];
	[self setCurrentView:nil];
	[[self window] setDelegate:nil];
	[_tagStack clear];
	[[ViMarkManager sharedManager] removeStack:_tagStack];
	[__windowControllers removeObject:self];
}

- (ViDocumentView *)currentDocumentView
{
	if ([_currentView isKindOfClass:[ViDocumentView class]])
		return (ViDocumentView *)_currentView;
	return nil;
}

- (ViViewController *)currentView
{
	return _currentView;
}

- (void)setCurrentView:(ViViewController *)viewController
{
	[self willChangeCurrentView]; // if it wasn't called before
	[viewController retain];
	[_currentView release];
	_currentView = viewController;
	[self didChangeCurrentView];
}

/*
 * Closes a tab. All views in it should be closed already.
 */
- (void)closeTabController:(ViTabController *)tabController
{
	DEBUG(@"closing tab controller %@", tabController);

	NSInteger ndx = [tabView indexOfTabViewItemWithIdentifier:tabController];
	if (ndx != NSNotFound) {
		NSTabViewItem *item = [tabView tabViewItemAtIndex:ndx];
		[tabView removeTabViewItem:item];
		[self tabView:tabView didCloseTabViewItem:item];
		// tabController is now released (invalid)
	}
}

- (void)document:(NSDocument *)doc
     shouldClose:(BOOL)shouldClose
     contextInfo:(void *)contextInfo
{
	if (shouldClose)
		[(ViDocument *)doc closeAndWindow:(intptr_t)contextInfo];
}

/* almost, but not quite, like :quit */
- (IBAction)closeCurrent:(id)sender
{
	BOOL canCloseWindow = !self.window.isFullScreen;

	ViDocumentView *docView = [self currentDocumentView];

	/* If the current view is a document view, check if it's the last view for the document. */
	if (docView) {
		ViDocument *doc = [docView document];
		if (![self documentOpenElsewhere:doc] && [[doc views] count] == 1) {
			[doc canCloseDocumentWithDelegate:self
				      shouldCloseSelector:@selector(document:shouldClose:contextInfo:)
					      contextInfo:(void *)(intptr_t)canCloseWindow];
			return;
		}
	}

	[self closeDocumentView:[self currentView]
	       canCloseDocument:YES
		 canCloseWindow:canCloseWindow];
}

- (IBAction)closeCurrentDocument:(id)sender
{
	[self closeCurrentDocumentAndWindow:NO];
}

- (void)closeDocument:(ViDocument *)document andWindow:(BOOL)canCloseWindow
{
	[document canCloseDocumentWithDelegate:self
			   shouldCloseSelector:@selector(document:shouldClose:contextInfo:)
				   contextInfo:(void *)(intptr_t)canCloseWindow];
}

/* :bdelete and ctrl-cmd-w */
- (void)closeCurrentDocumentAndWindow:(BOOL)canCloseWindow
{
	ViDocument *doc = [self currentDocument];
	if (doc)
		[self closeDocument:doc andWindow:canCloseWindow];
	else
		[self closeDocumentView:[self currentView]
		       canCloseDocument:NO
			 canCloseWindow:canCloseWindow];
}

/*
 * Close the current view (but not the document!) unless this is
 * the last view in the window.
 * Called by C-w c.
 */
- (BOOL)closeCurrentViewUnlessLast
{
	ViViewController *viewController = [self currentView];
	if ([tabView numberOfTabViewItems] > 1 || [[viewController.tabController views] count] > 1) {
		[self closeDocumentView:viewController
		       canCloseDocument:NO
			 canCloseWindow:NO];
		return YES;
	}
	return NO;
}

- (void)unlistDocument:(ViDocument *)document
{
	DEBUG(@"unlisting document %@", document);

	NSInteger ndx = [[openFilesButton menu] indexOfItemWithRepresentedObject:document];
	if (ndx != -1)
		[[openFilesButton menu] removeItemAtIndex:ndx];
	if ([_documents containsObject:document]) {
		[_documents removeObject:document];
		[document closeWindowController:self];
		[document removeObserver:symbolController forKeyPath:@"symbols"];
	}
}

- (NSSet *)viewsOfDocument:(ViDocument *)document
{
	NSMutableSet *set = [NSMutableSet set];
	for (ViDocumentView *view in [document views]) {
		if ([[view tabController] window] == [self window]) {
			[set addObject:view];
		}
	}
	return set;
}

- (void)closeOrUnlistDocument:(ViDocument *)document unlessVisible:(BOOL)unlessVisible
{
	if ([[self viewsOfDocument:document] count] == 0 || !unlessVisible) {
		DEBUG(@"closed last view of document %@, closing document", document);
		if ([self documentOpenElsewhere:document]) {
			DEBUG(@"document %@ open in other windows", document);
			[self unlistDocument:document];
		} else {
			[document close];
		}
	} else {
		DEBUG(@"document %@ has more views open: %@", document, [self viewsOfDocument:document]);
	}
}

- (ViDocument *)previouslyActiveDocumentVisible:(BOOL)mustBeVisible
{
	DEBUG(@"returning previously active document (currently %@) (%s be visible)",
	    [self currentDocument], mustBeVisible ? "MUST" : "must NOT");
	__block ViDocument *found = nil;
	[_jumpList enumerateJumpsBackwardsUsingBlock:^(ViMark *jump, BOOL *stop) {
		DEBUG(@"got jump %@", jump);
		ViDocument *doc = jump.document;
		if (doc && doc != [self currentDocument] && [_documents containsObject:doc] &&
		    (!mustBeVisible || [[doc views] count] > 0)) {
			found = doc;
			*stop = YES;
		}
	}];
	DEBUG(@"got previously active document %@", found);
	return found;
}

- (void)closeDocumentView:(ViViewController *)viewController
	 canCloseDocument:(BOOL)canCloseDocument
	   canCloseWindow:(BOOL)canCloseWindow
{
	DEBUG(@"closing view controller %@, and document: %s, and window: %s, from window %@",
		viewController, canCloseDocument ? "YES" : "NO", canCloseWindow ? "YES" : "NO",
		[self window]);

	if (viewController == nil)
		[[self window] close];

	ViDocument *prevdoc = [self previouslyActiveDocumentVisible:!canCloseDocument];

	[self willChangeCurrentView];
	if (viewController == [self currentView])
		[self setCurrentView:nil];

	ViDocument *doc = nil;
	if ([viewController isKindOfClass:[ViDocumentView class]])
		doc = [(ViDocumentView *)viewController document];

	ViTabController *tabController = [viewController tabController];
	[tabController closeView:viewController]; // releases viewController

	/* If this was the last view of the document, close the document too. */
	if (canCloseDocument && doc) {
		[self closeOrUnlistDocument:doc unlessVisible:YES];
	}

	/* If this was the last view in the tab, close the tab too. */
	if ([[tabController views] count] == 0) {
		DEBUG(@"got previously active document %@", prevdoc);

		if ([tabView numberOfTabViewItems] <= 1) {
			DEBUG(@"closed last tab, got documents: %@", _documents);
			if (prevdoc == nil) {
				prevdoc = [_documents anyObject];
				DEBUG(@"now got previously active document %@", prevdoc);
			}

			if (prevdoc) {
				[self displayDocument:prevdoc positioned:ViViewPositionReplace];
			} else if (canCloseWindow) {
				[[self window] close];
			} else {
				ViDocument *newDoc = [[ViDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:NO
															       error:nil];
				newDoc.isTemporary = YES;
				[self displayDocument:newDoc positioned:ViViewPositionReplace];
			}
		} else {
			DEBUG(@"got prevdoc %@", prevdoc);
			[self displayDocument:prevdoc positioned:ViViewPositionDefault];

			BOOL preJumping = _jumping;
			_jumping = NO;
			[self closeTabController:tabController];
			_jumping = preJumping;
		}
		/* XXX: do not reference self here, we might have closed the window and deallocated the window contorller! */
	} else if (tabController == [self selectedTabController]) {
		/* Select another document view in the same tab. */
		[self selectDocumentView:tabController.selectedView];
	}
}

/*
 * Called by the document when it closes.
 * Removes all views of the document in this window.
 */
- (void)didCloseDocument:(ViDocument *)document andWindow:(BOOL)canCloseWindow
{
	DEBUG(@"closing document %@, and window: %s", document, canCloseWindow ? "YES" : "NO");

	[self unlistDocument:document];

	/* Close all views of the document in this window. */
	ViDocumentView *docView;
	NSMutableSet *set = [NSMutableSet set];
	for (docView in [document views]) {
		DEBUG(@"docview %@ in window %@", docView, [[docView tabController] window]);
		if ([[docView tabController] window] == [self window]) {
			[set addObject:docView];
		}
	}

	DEBUG(@"closing remaining views in window %@: %@", [self window], set);
	for (docView in set) {
		[self closeDocumentView:docView
		       canCloseDocument:YES /* The document is already being closed. */
			 canCloseWindow:canCloseWindow];
	}
}

- (void)documentController:(NSDocumentController *)docController
	       didCloseAll:(BOOL)didCloseAll
	     tabController:(void *)tabController
{
	DEBUG(@"force close all views in tab %@: %s", (ViTabController *)tabController, didCloseAll ? "YES" : "NO");
	if (didCloseAll) {
		/* Close any views left in this tab. Do not ask for confirmation. */
		while ([[(ViTabController *)tabController views] count] > 0) {
			ViViewController *viewController = [[(ViTabController *)tabController views] objectAtIndex:0];
			[self willChangeCurrentView];
			if (viewController == [self currentView]) {
				[self setCurrentView:nil];
			}

			ViDocument *doc = nil;
			if ([viewController isKindOfClass:[ViDocumentView class]]) {
				doc = [(ViDocumentView *)viewController document];
			}

			[(ViTabController *)tabController closeView:viewController]; // releases viewController

			/* If this was the last view of the document, close the document too. */
			if (doc) {
				[self closeOrUnlistDocument:doc unlessVisible:YES];
			}
		}
		[self closeTabController:(ViTabController *)tabController];
	}
	[(ViTabController *)tabController release];
}

- (BOOL)tabView:(NSTabView *)aTabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
	ViTabController *tabController = [tabViewItem identifier];

	/*
	 * Directly close all views for documents that either
	 *  a) have another view in another tab, or
	 *  b) is not modified
	 *
	 * For any document that can't directly be closed, ask the user.
	 */

	DEBUG(@"closing tab controller %@", tabController);

	/* If closing the last tab, close the window. */
	if ([tabView numberOfTabViewItems] == 1) {
		[[self window] performClose:nil];
		return NO;
	}

	NSSet *set = [tabController representedObjectsOfClass:[ViDocument class] matchingCriteria:^(id obj) {
		ViDocument *document = obj;

		if (![document isDocumentEdited])
			return NO;

		ViDocumentView *otherDocView;
		for (otherDocView in [document views])
			if (otherDocView.tabController != tabController)
				break;
		return (BOOL)(otherDocView == nil);
	}];

	[[NSDocumentController sharedDocumentController] closeAllDocumentsInSet:set
								   withDelegate:self
							    didCloseAllSelector:@selector(documentController:didCloseAll:tabController:)
								    contextInfo:[tabController retain]];

	return NO;
}

- (void)tabView:(NSTabView *)aTabView willCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
}

- (void)tabView:(NSTabView *)aTabView didCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
	[tabViewItem unbind:@"label"];
	[tabViewItem setIdentifier:nil];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	NSWindow *keyWindow = [[NSApp delegate] keyWindowBeforeMainMenuTracking];
	BOOL isDocWindow = [[keyWindow windowController] isKindOfClass:[ViWindowController class]];

	return isDocWindow;
}

#pragma mark -
#pragma mark Switching documents

- (void)firstResponderChanged:(NSNotification *)notification
{
	NSView *view = [notification object];
	ViViewController *viewController = [self viewControllerForView:view];
	if (viewController) {
		if (_parser.partial) {
			[self message:@"Vi command interrupted."];
			[_parser reset];
		}
		[self didSelectViewController:viewController];
	}

	if (_exModal && view != exField) {
		[NSApp abortModal];
		_exModal = NO;
	}
}

- (void)didSelectDocument:(ViDocument *)document
{
	if (document == nil)
		return;

	// XXX: currentView is the *previously* current view
	if ([[self currentDocumentView] document] == document)
		return;

	[[ViEventManager defaultManager] emit:ViEventWillSelectDocument for:self with:self, document, nil];
	[[self document] removeWindowController:self];
	[document addWindowController:self];
	[self setDocument:document];

	NSInteger ndx = [[openFilesButton menu] indexOfItemWithRepresentedObject:document];
	if (ndx != -1)
		[openFilesButton selectItemAtIndex:ndx];

	// update symbol list
	[symbolController didSelectDocument:document];

	[[ViEventManager defaultManager] emit:ViEventDidSelectDocument for:self with:self, document, nil];
}

- (NSURL *)alternateURL
{
	return _alternateMark.url;
}

- (ViDocument *)alternateDocument
{
	return _alternateMark.document;
}

- (void)willChangeCurrentView
{
	if (_alternateMarkCandidate == nil &&
	    [[self currentView] isKindOfClass:[ViDocumentView class]]) {
		[self setAlternateMarkCandidate:[(ViTextView *)[[self currentView] innerView] currentMark]];
		_alternateMarkCandidate.title = @"_alternateMarkCandidate";
		DEBUG(@"alt mark candidate is %@", _alternateMarkCandidate);
	}
}

- (void)didChangeCurrentView
{
	ViViewController *viewController = [self currentView];
	if (viewController == nil)
		return;

	if ([viewController isKindOfClass:[ViDocumentView class]]) {
		ViDocumentView *docView = (ViDocumentView *)viewController;

		if (![_alternateMarkCandidate.url isEqual:[(ViDocument *)docView.document fileURL]]) {
			DEBUG(@"previous document mark %@ -> %@", _alternateMark, _alternateMarkCandidate);
			[self setAlternateMark:_alternateMarkCandidate];
			_alternateMark.title = @"_alternateMark";
		}
	}

	[_alternateMarkCandidate release];
	_alternateMarkCandidate = nil;
}

- (void)didSelectViewController:(ViViewController *)viewController
{
	DEBUG(@"did select view %@", viewController);

	if (viewController == [self currentView])
		return;

	[[ViEventManager defaultManager] emit:ViEventWillSelectView for:self with:self, viewController, nil];

	if ([viewController isKindOfClass:[ViDocumentView class]]) {
		ViDocumentView *docView = (ViDocumentView *)viewController;
		if (!_jumping)
			[[docView textView] pushCurrentLocationOnJumpList];
		[self didSelectDocument:[docView document]];
		[symbolController updateSelectedSymbolForLocation:[[docView textView] caret]];
	}

	ViTabController *tabController = [viewController tabController];
	[tabController setSelectedView:viewController];

	if (tabController == [[self currentView] tabController] &&
	    _currentView != [tabController previousView])
		[tabController setPreviousView:_currentView];

	[self setCurrentView:viewController];

	[[ViEventManager defaultManager] emit:ViEventDidSelectView for:self with:self, viewController, nil];
}

/*
 * Selects the tab holding the given view and focuses the view.
 */
- (ViViewController *)selectDocumentView:(ViViewController *)viewController
{
	DEBUG(@"selecting document view %@", viewController);
	ViTabController *tabController = [viewController tabController];

	NSInteger ndx = [tabView indexOfTabViewItemWithIdentifier:tabController];
	if (ndx == NSNotFound)
		return nil;

	NSTabViewItem *item = [tabView tabViewItemAtIndex:ndx];
	[tabView selectTabViewItem:item];

	// Focus the text view
	[[self window] makeFirstResponder:[viewController innerView]];

	return viewController;
}

- (void)tabView:(NSTabView *)aTabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	[self willChangeCurrentView];
	ViTabController *tabController = [tabViewItem identifier];
	[[ViEventManager defaultManager] emit:ViEventWillSelectTab for:self with:self, tabController, nil];
}

- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	ViTabController *tabController = [tabViewItem identifier];
	[self selectDocumentView:tabController.selectedView];
	[[ViEventManager defaultManager] emit:ViEventDidSelectTab for:self with:self, tabController, nil];
}

/*
 * Returns the most appropriate view for the given document.
 * Returns nil if no view of the document is currently open.
 */
- (ViDocumentView *)viewForDocument:(ViDocument *)document
{
	if (!_isLoaded || document == nil)
		return nil;

	/* Check if the current view contains the document. */
	if ([[self currentDocumentView] document] == document)
		return [self currentDocumentView];

	/* Check if current tab has a view of the document. */
	ViTabController *tabController = [self selectedTabController];
	ViDocumentView *docView = [tabController viewWithDocument:document];
	if (docView)
		return docView;

	/* Select any existing view of the document. */
	if ([[document views] count] > 0) {
		docView = [[document views] anyObject];
		/*
		 * If the tab with the document view contains more views
		 * of the same document, prefer the selected view in the
		 * (randomly) selected tab controller.
		 */
		ViViewController *selView = [[docView tabController] selectedView];
		if ([selView isKindOfClass:[ViDocumentView class]] &&
		    [(ViDocumentView *)selView document] == document)
			return (ViDocumentView *)selView;
		return docView;
	}

	/* No open view for the given document. */
	return nil;
}

- (IBAction)selectNextTab:(id)sender
{
	NSArray *tabs = [tabBar representedTabViewItems];
	NSInteger num = [tabs count];
	if (num <= 1)
		return;

	NSInteger i;
	for (i = 0; i < num; i++)
	{
		if ([tabs objectAtIndex:i] == [tabView selectedTabViewItem])
		{
			if (++i >= num)
				i = 0;
			[tabView selectTabViewItem:[tabs objectAtIndex:i]];
			break;
		}
	}
}

- (IBAction)selectPreviousTab:(id)sender
{
	NSArray *tabs = [tabBar representedTabViewItems];
	NSInteger num = [tabs count];
	if (num <= 1)
		return;

	NSInteger i;
	for (i = 0; i < num; i++)
	{
		if ([tabs objectAtIndex:i] == [tabView selectedTabViewItem])
		{
			if (--i < 0)
				i = num - 1;
			[tabView selectTabViewItem:[tabs objectAtIndex:i]];
			break;
		}
	}
}

- (void)selectTabAtIndex:(NSInteger)anIndex
{
	NSArray *tabs = [tabBar representedTabViewItems];
	if (anIndex < [tabs count])
		[tabView selectTabViewItem:[tabs objectAtIndex:anIndex]];
}

- (ViTabController *)selectedTabController
{
	return [[tabView selectedTabViewItem] identifier];
}

/*
 * Called from document popup in the toolbar.
 * Changes the document in the current view to the selected document.
 */
- (void)switchToDocumentAction:(id)sender
{
	ViDocument *doc = [sender representedObject];
	if (doc)
		[self displayDocument:doc positioned:ViViewPositionReplace];
}

- (ViDocument *)documentForURL:(NSURL *)url
{
	for (ViDocument *doc in _documents)
		if ([url isEqual:[doc fileURL]])
			return doc;
	return nil;
}

- (ViDocumentView *)displayDocument:(ViDocument *)doc positioned:(ViViewPosition)position
{
	if (!_isLoaded || doc == nil)
		return nil;

	/* Make sure the document is registered in this window. */
	[self addDocument:doc];

	ViDocumentView *docView = nil;
	BOOL prefertabs = [[NSUserDefaults standardUserDefaults] boolForKey:@"prefertabs"];
	ViTabController *tabController = [self selectedTabController];

	/* Can't replace named or edited documents, or documents with multiple views. */
#define CLOSE_CANDIDATE_INVALID(doc) \
	(doc == nil || [doc fileURL] || [doc isDocumentEdited] || [[doc views] count] > 1)

	if ([tabView numberOfTabViewItems] == 0) {
		/*
		 * Special case: if there are no tabs open, just create a new tab for
		 * the document, regardless of positioning.
		 * XXX: when can this happen?
		 */
		return [self createTabForDocument:doc];
	} else if ([tabView numberOfTabViewItems] == 1 && [[tabController views] count] == 0) {
		/*
		 * Special case: if there is only one tab without any views, just switch to
		 * the document, regardless of positioning.
		 * This should only happen when the last view is closed in a window.
		 */
		DEBUG(@"no views in tab %@, creating new view for document %@", tabController, doc);
		docView = (ViDocumentView *)[tabController replaceView:nil
							      withView:[doc makeViewWithParser:_parser]];
	} else if (position >= ViViewPositionSplitLeft && position <= ViViewPositionSplitBelow) {
		/*
		 * Splitting never replaces an untitled document.
		 */
		docView = (ViDocumentView *)[tabController splitView:[self currentView]
							    withView:[doc makeViewWithParser:_parser]
							  positioned:position];
	} else {
		/*
		 * Find a suitable untitled and unchanged document we can replace.
		 * Don't replace an untitled document with another untitled document.
		 */
		ViDocument *closeThisDocument = nil;
		ViTabController *tabController = [self selectedTabController];
		BOOL forceSwitch = NO;
		if ([doc fileURL]) {
			if ((position == ViViewPositionTab || (position == ViViewPositionDefault && prefertabs))) {
				/* Try current document. */
				if ([[tabController views] count] == 1 &&
				    [[[tabController views] objectAtIndex:0] respondsToSelector:@selector(document)])
					closeThisDocument = [[[tabController views] objectAtIndex:0] document];
				if (CLOSE_CANDIDATE_INVALID(closeThisDocument)) {
					closeThisDocument = nil;
					/* Try document in last tab. */
					tabController = [(NSTabViewItem *)[[tabBar representedTabViewItems] lastObject] identifier];
					if ([[tabController views] count] == 1 &&
					    [[[tabController views] objectAtIndex:0] respondsToSelector:@selector(document)])
						closeThisDocument = [[[tabController views] objectAtIndex:0] document];
				} else
					forceSwitch = YES;
			} else {
				/* Otherwise we're switching the current view to the document. */
				/* Try the current document. */
				closeThisDocument = [self currentDocument];
			}
		}

		if (CLOSE_CANDIDATE_INVALID(closeThisDocument))
			closeThisDocument = nil;

		if (closeThisDocument)
			[tabBar disableAnimations];

		if (position == ViViewPositionDefault) {
			/*
			 * Select any existing view of the document, or
			 * if no view is available in the window, switch
			 * or create tab depending on preference.
			 */
			docView = [self viewForDocument:doc];
			if (docView == nil)
				position = ViViewPositionPreferred;

		}

		if (forceSwitch || position == ViViewPositionReplace || (position == ViViewPositionPreferred && !prefertabs)) {
			if ([[[self currentDocumentView] document] isEqual:doc])
				docView = [self currentDocumentView];
			else
				docView = (ViDocumentView *)[tabController replaceView:[self currentView]
									      withView:[doc makeViewWithParser:_parser]];
		} else if (position == ViViewPositionTab || (position == ViViewPositionPreferred && prefertabs)) {
			docView = [self createTabForDocument:doc];
		}

		if (closeThisDocument) {
			[closeThisDocument closeAndWindow:NO];
			[tabBar enableAnimations];
		}
	}

	return (ViDocumentView *)[self selectDocumentView:docView];
}

- (ViDocumentView *)displayDocument:(ViDocument *)doc
{
	return [self displayDocument:doc positioned:ViViewPositionDefault];
}

- (BOOL)gotoMark:(ViMark *)mark positioned:(ViViewPosition)viewPosition recordJump:(BOOL)isJump
{
	if (mark == nil)
		return NO;

	/* XXX: prevent pushing an extraneous jump on the list. */
	_jumping = !isJump;

	ViViewController *viewController = [self currentView];
	if (!_jumping && [viewController isKindOfClass:[ViDocumentView class]])
		[[(ViDocumentView *)viewController textView] pushCurrentLocationOnJumpList];

	DEBUG(@"goto mark %@ (view is %@)", mark, mark.view);

	[[mark retain] autorelease];

	if (mark.view && [[NSUserDefaults standardUserDefaults] boolForKey:@"prefertabs"]) {
		/* Go to an existing view. View position is ignored. */
		viewController = [self selectDocumentView:mark.view];
	} else {
		ViDocument *doc = mark.document;
		if (doc == nil) {
			if (mark.url == nil) {
				_jumping = NO;
				return NO;
			}

			NSError *error = nil;
			ViDocumentController *ctrl = [NSDocumentController sharedDocumentController];
			doc = [ctrl openDocumentWithContentsOfURL:mark.url
							  display:NO
							    error:&error];
			if (error) {
				[NSApp presentError:error];
				_jumping = NO;
				return NO;
			}
		}

		viewController = [self displayDocument:doc positioned:viewPosition];
	}

	_jumping = NO;
	return [(ViTextView *)[viewController innerView] gotoMark:mark];
}

- (BOOL)gotoMark:(ViMark *)mark positioned:(ViViewPosition)viewPosition
{
	return [self gotoMark:mark positioned:viewPosition recordJump:YES];
}

- (BOOL)gotoMark:(ViMark *)mark
{
	return [self gotoMark:mark positioned:ViViewPositionDefault recordJump:YES];
}

- (BOOL)gotoURL:(NSURL *)url
           line:(NSUInteger)line
         column:(NSUInteger)column
{
	return [self gotoMark:[ViMark markWithURL:url line:line column:column]];
}

- (BOOL)gotoURL:(NSURL *)url
{
	return [self gotoMark:[ViMark markWithURL:url]];
}

#pragma mark -
#pragma mark View Splitting

- (IBAction)splitViewHorizontally:(id)sender
{
	ViViewController *viewController = [self currentView];
	if (viewController == nil)
		return;

	// Only document views support splitting (?)
	if ([viewController isKindOfClass:[ViDocumentView class]]) {
		ViTabController *tabController = [viewController tabController];
		[tabController splitView:viewController vertically:NO];
		[self selectDocumentView:viewController];
	}
}

- (IBAction)splitViewVertically:(id)sender
{
	ViViewController *viewController = [self currentView];
	if (viewController == nil)
		return;

	// Only document views support splitting (?)
	if ([viewController isKindOfClass:[ViDocumentView class]]) {
		ViTabController *tabController = [viewController tabController];
		[tabController splitView:viewController vertically:YES];
		[self selectDocumentView:viewController];
	}
}

- (ViViewController *)viewControllerForView:(NSView *)aView
{
	if (aView == nil)
		return nil;

	NSArray *tabs = [tabBar representedTabViewItems];
	for (NSTabViewItem *item in tabs) {
		ViViewController *viewController = [[item identifier] viewControllerForView:aView];
		if (viewController)
			return viewController;
	}

	if ([aView respondsToSelector:@selector(superview)])
		return [self viewControllerForView:[aView superview]];

	DEBUG(@"***** View %@ not in a view controller", aView);
	return nil;
}

- (BOOL)normalizeSplitViewSizesInCurrentTab
{
	ViViewController *viewController = [self currentView];
	if (viewController == nil)
		return NO;

	ViTabController *tabController = [viewController tabController];
	[tabController normalizeAllViews];
	return YES;
}

- (BOOL)closeOtherViews
{
	ViViewController *viewController = [self currentView];
	if (viewController == nil)
		return NO;

	ViTabController *tabController = [viewController tabController];
	if ([[tabController views] count] == 1) {
		[self message:@"Already only one window"];
		return NO;
	}
	[tabController closeViewsOtherThan:viewController];
	return YES;
}

- (BOOL)moveCurrentViewToNewTab
{
	ViViewController *viewController = [self currentView];
	if (viewController == nil)
		return NO;

	ViTabController *tabController = [viewController tabController];
	if ([[tabController views] count] == 1) {
		[self message:@"Already only one view"];
		return NO;
	}

	[viewController retain];
	[tabController detachView:viewController];
	[self createTabWithViewController:viewController];
	[viewController release];
	return YES;
}

- (IBAction)moveCurrentViewToNewTabAction:(id)sender
{
	[self moveCurrentViewToNewTab];
}


extern BOOL __makeNewWindowInsteadOfTab;
- (BOOL)moveCurrentViewToNewWindow
{
	ViViewController *viewController = [self currentView];
	if (viewController == nil)
		return NO;

	ViTabController *tabController = [viewController tabController];

	if ([[tabBar representedTabViewItems] count] <= 1 && [[tabController views] count] == 1) {
		[self message:@"Already only one view"];
		return NO;
	}

	[viewController retain];
	[tabController detachView:viewController];

	__makeNewWindowInsteadOfTab = YES;
	ViWindowController *winCon = [[[ViWindowController alloc] init] autorelease];
	__makeNewWindowInsteadOfTab = NO;

	[winCon setBaseURL:[self baseURL]];
	[winCon createTabWithViewController:viewController];
	[[winCon window] makeKeyAndOrderFront:nil];

	if ([[tabController views] count] == 0) {
		[self closeTabController:tabController];
	} else {
		[self selectDocumentView:tabController.selectedView];
	}

	[viewController release];
	return YES;
}

- (IBAction)moveCurrentViewToNewWindowAction:(id)sender
{
	[self moveCurrentViewToNewWindow];
}

- (BOOL)selectViewAtPosition:(ViViewOrderingMode)position relativeTo:(id)aView
{
	ViViewController *viewController, *otherViewController;
	if ([aView respondsToSelector:@selector(tabController)])
		viewController = aView;
	else
		viewController = [self viewControllerForView:aView];
	otherViewController = [[viewController tabController] viewAtPosition:position
								  relativeTo:[viewController view]];
	if (otherViewController == nil)
		return NO;
	[self selectDocumentView:otherViewController];
	return YES;
}

- (ViDocumentView *)splitVertically:(BOOL)isVertical
			    andOpen:(id)filenameOrURL
		 orSwitchToDocument:(ViDocument *)doc
		    allowReusedView:(BOOL)allowReusedView
{
	ViDocumentController *ctrl = [ViDocumentController sharedDocumentController];
	BOOL newDoc = YES;

	NSError *err = nil;
	if (filenameOrURL) {
		NSURL *url;
		if ([filenameOrURL isKindOfClass:[NSURL class]])
			url = filenameOrURL;
		else
			url = [ctrl normalizePath:filenameOrURL
				       relativeTo:_baseURL
					    error:&err];
		if (url && !err) {
			doc = [ctrl documentForURL:url];
			if (doc)
				newDoc = NO;
			else
				doc = [ctrl openDocumentWithContentsOfURL:filenameOrURL
								  display:NO
								    error:&err];
		}
	} else if (doc == nil) {
		doc = [ctrl openUntitledDocumentAndDisplay:NO error:&err];
		doc.isTemporary = YES;
	} else
		newDoc = NO;

	if (err) {
		[self message:@"%@", [err localizedDescription]];
		return nil;
	}

	if (doc) {
		ViViewController *viewController = [self currentView];
		ViTabController *tabController = [viewController tabController];
		ViDocumentView *newDocView = nil;

		if (allowReusedView && !newDoc) {
			/* Check if the tab already has a view for this document. */
			newDocView = [tabController viewWithDocument:doc];
			[self selectDocumentView:newDocView];
		}

		if (newDocView == nil)
			newDocView = [self displayDocument:doc
						positioned:isVertical ? ViViewPositionSplitVertical : ViViewPositionSplitHorizontal];

		if (!newDoc && [viewController isKindOfClass:[ViDocumentView class]]) {
			/*
			 * If we're splitting a document, position
			 * the caret in the new view appropriately.
			 */
			ViDocumentView *docView = (ViDocumentView *)viewController;
			[[newDocView textView] setCaret:[[docView textView] caret]];
			[[newDocView textView] scrollRangeToVisible:NSMakeRange([[docView textView] caret], 0)];
		}

		return newDocView;
	}

	return nil;
}

- (ViDocumentView *)splitVertically:(BOOL)isVertical
			    andOpen:(id)filenameOrURL
{
	return [self splitVertically:isVertical
			     andOpen:filenameOrURL
		  orSwitchToDocument:nil
		     allowReusedView:YES];
}

- (ViDocumentView *)splitVertically:(BOOL)isVertical
			    andOpen:(id)filenameOrURL
		 orSwitchToDocument:(ViDocument *)doc;
{
	return [self splitVertically:isVertical
			     andOpen:filenameOrURL
		  orSwitchToDocument:doc
		     allowReusedView:NO];
}

#pragma mark -
#pragma mark Split view delegate methods

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
	if (subview == explorerView || subview == symbolsView)
		return YES;
	return NO;
}

- (BOOL)splitView:(NSSplitView *)sender shouldHideDividerAtIndex:(NSInteger)dividerIndex
{
	if (sender == splitView)
		return YES;
	return NO;
}

- (CGFloat)splitView:(NSSplitView *)sender
constrainMinCoordinate:(CGFloat)proposedMin
         ofSubviewAt:(NSInteger)offset
{
	if (sender == splitView) {
		NSView *view = [[sender subviews] objectAtIndex:offset];
		if (view == explorerView)
			return 100;
		NSRect frame = [sender frame];
		return IMAX(frame.size.width - 500, 0);
	}

	return proposedMin;
}

- (CGFloat)splitView:(NSSplitView *)sender
constrainMaxCoordinate:(CGFloat)proposedMax
         ofSubviewAt:(NSInteger)offset
{
	if (sender == splitView) {
		NSView *view = [[sender subviews] objectAtIndex:offset];
		if (view == explorerView)
			return 500;
		return IMAX(proposedMax - 100, 0);
	} else
		return proposedMax;
}

- (BOOL)splitView:(NSSplitView *)sender
shouldCollapseSubview:(NSView *)subview
forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex
{
	// collapse both side views, but not the main view
	if (subview == explorerView || subview == symbolsView)
		return YES;
	return NO;
}

- (BOOL)splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView *)subview
{
	if (subview == explorerView || subview == symbolsView)
		return NO;
	return YES;
}

- (NSRect)splitView:(NSSplitView *)sender
additionalEffectiveRectOfDividerAtIndex:(NSInteger)dividerIndex
{
	if (sender != splitView)
		return NSZeroRect;

	NSView *leftView = [[sender subviews] objectAtIndex:dividerIndex];
	NSView *rightView = [[sender subviews] objectAtIndex:dividerIndex + 1];

	NSRect frame = [sender frame];
	NSRect resizeRect;
	if (leftView == explorerView && [explorer explorerIsOpen])
		resizeRect = [projectResizeView frame];
	else if (rightView == symbolsView && [symbolController symbolListIsOpen]) {
		resizeRect = [symbolsResizeView frame];
		resizeRect.origin = [sender convertPoint:resizeRect.origin
					        fromView:symbolsResizeView];
	} else
		return NSZeroRect;

	resizeRect.origin.y = NSHeight(frame) - NSHeight(resizeRect);
	return resizeRect;
}

- (void)splitView:(NSSplitView *)aSplitView resizeSubviewsWithOldSize:(NSSize)oldSize
{
	[aSplitView adjustSubviews];
}

#pragma mark -
#pragma mark Symbol List

- (IBAction)toggleSymbolList:(id)sender
{
	[symbolController toggleSymbolList:sender];
}

- (IBAction)searchSymbol:(id)sender
{
	[symbolController searchSymbol:sender];
}

- (IBAction)focusSymbols:(id)sender
{
	[symbolController focusSymbols:sender];
}

- (NSMutableArray *)symbolsFilteredByPattern:(NSString *)pattern
{
	ViRegexp *rx = [ViRegexp regexpWithString:pattern options:ONIG_OPTION_IGNORECASE];

	NSMutableArray *syms = [NSMutableArray array];
	for (ViDocument *doc in _documents)
		for (ViMark *s in doc.symbols)
			if ([rx matchInString:s.title])
				[syms addObject:s];

	return syms;
}

#pragma mark -

- (IBAction)searchFiles:(id)sender
{
	[explorer searchFiles:sender];
}

- (IBAction)focusExplorer:(id)sender
{
	[explorer focusExplorer:sender];
}

- (BOOL)focus_explorer:(ViCommand *)command
{
	[explorer focusExplorer:nil];
	return YES;
}

- (IBAction)toggleExplorer:(id)sender
{
	[explorer toggleExplorer:sender];
}

#pragma mark -
#pragma mark Jumplist navigation

- (IBAction)navigateJumplist:(id)sender
{
	ViMark *here = nil;

	ViViewController *viewController = [self currentView];
	if ([viewController isKindOfClass:[ViDocumentView class]]) {
		ViTextView *tv = [(ViDocumentView *)viewController textView];
		if (tv == nil)
			return;
		here = [tv currentMark];
	}

	if ([sender selectedSegment] == 0)
		[self gotoMark:[_jumpList backwardFrom:here] positioned:ViViewPositionDefault recordJump:NO];
	else
		[self gotoMark:[_jumpList forward] positioned:ViViewPositionDefault recordJump:NO];
}

- (void)updateJumplistNavigator
{
	[jumplistNavigator setEnabled:![_jumpList atEnd] forSegment:1];
	[jumplistNavigator setEnabled:![_jumpList atBeginning] forSegment:0];
}

- (void)jumpList:(ViJumpList *)aJumpList added:(ViMark *)jump
{
	[self updateJumplistNavigator];
}

- (void)jumpList:(ViJumpList *)aJumpList goto:(ViMark *)jump
{
	[self updateJumplistNavigator]; // observe _tagStack.list.selectionIndexes instead
}

#pragma mark -
#pragma mark Vi actions

- (BOOL)changeFontSize:(BOOL)bigger
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSInteger fs = [defs integerForKey:@"fontsize"] + (bigger ? 1 : -1);
	if (fs <= 1)
		return NO;
	[defs setInteger:fs forKey:@"fontsize"];
	return YES;
}

- (IBAction)increaseFontsizeAction:(id)sender
{
	[self changeFontSize:YES];
}

- (IBAction)decreaseFontsizeAction:(id)sender
{
	[self changeFontSize:NO];
}

- (BOOL)increase_fontsize:(ViCommand *)command
{
	return [self changeFontSize:YES];
}

- (BOOL)decrease_fontsize:(ViCommand *)command
{
	return [self changeFontSize:NO];
}

- (BOOL)window_left:(ViCommand *)command
{
	return [self selectViewAtPosition:ViViewLeft relativeTo:[self currentView]];
}

- (BOOL)window_down:(ViCommand *)command
{
	return [self selectViewAtPosition:ViViewDown relativeTo:[self currentView]];
}

- (BOOL)window_up:(ViCommand *)command
{
	return [self selectViewAtPosition:ViViewUp relativeTo:[self currentView]];
}

- (BOOL)window_right:(ViCommand *)command
{
	return [self selectViewAtPosition:ViViewRight relativeTo:[self currentView]];
}

- (BOOL)window_last:(ViCommand *)command
{
	ViTabController *tabController = [[self currentView] tabController];
	ViViewController *prevView = tabController.previousView;
	if (prevView == nil)
		return NO;
	[self selectDocumentView:prevView];
	return YES;
}

- (BOOL)window_next:(ViCommand *)command
{
	ViTabController *tabController = [[self currentView] tabController];
	ViViewController *nextView = [tabController nextViewClockwise:YES
							   relativeTo:[[self currentView] view]];
	if (nextView == nil)
		return NO;
	[self selectDocumentView:nextView];
	return YES;
}

- (BOOL)window_previous:(ViCommand *)command
{
	ViTabController *tabController = [[self currentView] tabController];
	ViViewController *nextView = [tabController nextViewClockwise:NO
							   relativeTo:[[self currentView] view]];
	if (nextView == nil)
		return NO;
	[self selectDocumentView:nextView];
	return YES;
}

- (BOOL)window_close:(ViCommand *)command
{
	return [self ex_close:nil] == nil;
}

- (BOOL)window_split:(ViCommand *)command
{
	return [self ex_split:nil] == nil;
}

- (BOOL)window_vsplit:(ViCommand *)command
{
	return [self ex_vsplit:nil] == nil;
}

- (BOOL)window_new:(ViCommand *)command
{
	return [self ex_new:nil] == nil;
}

- (BOOL)window_totab:(ViCommand *)command
{
	return [self moveCurrentViewToNewTab];
}

- (BOOL)window_towindow:(ViCommand *)command
{
	return [self moveCurrentViewToNewWindow];
}

- (BOOL)window_normalize:(ViCommand *)command
{
	return [self normalizeSplitViewSizesInCurrentTab];
}

- (BOOL)window_only:(ViCommand *)command
{
	return [self closeOtherViews];
}

- (BOOL)next_tab:(ViCommand *)command
{
	if (command.count)
		[self selectTabAtIndex:command.count - 1];
	else
		[self selectNextTab:nil];
	return YES;
}

- (BOOL)previous_tab:(ViCommand *)command
{
	[self selectPreviousTab:nil];
	return YES;
}

/* syntax: ctrl-^ */
- (BOOL)switch_file:(ViCommand *)command
{
	DEBUG(@"alternate mark is %@", _alternateMark);
	[self gotoMark:_alternateMark positioned:ViViewPositionPreferred];
	return YES;
}

/* syntax: cmd-[0-9] */
- (BOOL)switch_tab:(ViCommand *)command
{
	if (![command.mapping.parameter respondsToSelector:@selector(intValue)]) {
		MESSAGE(@"Unexpected parameter type %@",
		    NSStringFromClass([command.mapping.parameter class]));
		return NO;
	}
	int arg = [command.mapping.parameter intValue];
	[self selectTabAtIndex:arg];
	return YES;
}

#pragma mark -
#pragma mark Input of ex commands

- (void)textField:(ExTextField *)textField executeExCommand:(NSString *)exCommand
{
	if (exCommand) {
		_exString = [exCommand copy];
		if (_exModal)
			[NSApp abortModal];
	} else if (_exModal)
		[NSApp abortModal];

	_exBusy = NO;
}

- (NSString *)getExStringInteractivelyForCommand:(ViCommand *)command prefix:(NSString *)prefix
{
	ViMacro *macro = command.macro;

	if (_exBusy) {
		INFO(@"%s", "can't handle nested ex commands!");
		return nil;
	}

	_exBusy = YES;
	_exString = nil;

	[messageView setHidden:YES];
	[exField setHidden:NO];
 	[exField setSelectable:NO];
 	[exField setEditable:YES];
	[exField setStringValue:@""];

	/*
	 * The ExTextField resets the field editor when gaining focus (in becomeFirstResponder).
	 */
	[[self window] makeFirstResponder:exField];

	ViTextView *editor = (ViTextView *)[[self window] fieldEditor:YES forObject:exField];
	[editor setString:prefix ?: @""];
	[editor setCaret:[[editor textStorage] length]];

	if (macro) {
		NSInteger keyCode;
		while (_exBusy && (keyCode = [macro pop]) != -1)
			[editor.keyManager handleKey:keyCode];
	}

	if (_exBusy) {
		_exModal = YES;
		[NSApp runModalForWindow:[self window]];
		_exModal = NO;
		_exBusy = NO;
	}

	[exField setStringValue:@""];
	[exField setEditable:NO];
	[exField setHidden:YES];
	[messageView setHidden:NO];
	[self focusEditor];

	NSString *ret = [_exString autorelease];
	_exString = nil;
	return ret;
}

- (NSString *)getExStringInteractivelyForCommand:(ViCommand *)command
{
	return [self getExStringInteractivelyForCommand:command prefix:nil];
}

#pragma mark -
#pragma mark Ex actions

- (NSURL *)parseExFilename:(NSString *)filename
{
	if (filename == nil)
		return nil;

	NSError *error = nil;
	NSString *trimmed = [filename stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSURL *url = [[ViDocumentController sharedDocumentController] normalizePath:trimmed
									 relativeTo:_baseURL
									      error:&error];
	if (error) {
		[self message:@"%@: %@", trimmed, [error localizedDescription]];
		return nil;
	}

	return url;
}

- (id)ex_cd:(ExCommand *)command
{
	NSString *path = command.arg ?: @"~";
	__block NSError *retError = nil;
	__block BOOL sync = YES;
	[self checkBaseURL:[self parseExFilename:path] onCompletion:^(NSURL *url, NSError *error) {
		retError = error;
		if (url && !error) {
			[self setBaseURL:url];
			if (sync)
				[self ex_pwd:command];
			else
				[self message:@"%@", [self displayBaseURL]];
			[explorer browseURL:url andDisplay:NO];
		}
	}];
	sync = NO;

	return retError;
}

- (id)ex_pwd:(ExCommand *)command
{
	[command message:[self displayBaseURL]];
	return nil;
}

- (id)ex_close:(ExCommand *)command
{
	if (![self closeCurrentViewUnlessLast])
		return [ViError message:@"Cannot close last window"];
	return nil;
}

- (id)ex_edit:(ExCommand *)command
{
	ViDocumentController *docController = [ViDocumentController sharedDocumentController];
	NSError *error = nil;
	ViViewController *viewController = nil;

	if (command.arg == nil) {
		/* Re-open current file if force flag specified (:e!). */
		if (command.force) {
			ViDocument *doc = [self currentDocument];
			[doc revertDocumentToSaved:nil];
		}
	} else {
		NSURL *url = [self parseExFilename:command.arg];
		if (url) {
			ViDocument *doc;
			doc = [docController openDocumentWithContentsOfURL:url
								   display:NO
								     error:&error];
			if (doc) {
				if ([doc isKindOfClass:[ViProject class]]) {
					ViTabController *tabController = [self selectedTabController];
					if ([tabView numberOfTabViewItems] <= 1 &&
					    [[tabController views] count] <= 1 &&
					    [_documents count] <= 1 &&
					    [[_documents anyObject] fileURL] == nil &&
					    ![[_documents anyObject] isDocumentEdited]) {
						/* Just change project directory. */
						[doc close];
						[self setBaseURL:url];
						[self ex_pwd:command];
						[explorer browseURL:url andDisplay:NO];
					} else {
						[[doc nextRunloop] makeWindowControllers];
					}
				} else {
					viewController = [self displayDocument:doc positioned:ViViewPositionReplace];
				}
			}
		}
	}

	if (error == nil && command.plus_command && viewController) {
		ViTextView *text = (ViTextView *)[viewController innerView];
		if (![text evalExString:command.plus_command])
			return [NSNumber numberWithBool:NO];
	}

	return error;
}

- (id)ex_tabedit:(ExCommand *)command
{
	ViDocument *doc = nil;
	NSError *error = nil;
	ViDocumentController *docController = [ViDocumentController sharedDocumentController];

	if (command.arg == nil) {
		doc = [docController openUntitledDocumentAndDisplay:NO
							      error:&error];
		if (doc)
			doc.isTemporary = YES;
	} else {
		NSURL *url = [self parseExFilename:command.arg];
		if (url)
			doc = [docController openDocumentWithContentsOfURL:url
								   display:NO
								     error:&error];
	}

	if (doc) {
		if ([doc isKindOfClass:[ViProject class]]) {
			[[doc nextRunloop] makeWindowControllers];
		} else {
			ViDocumentView *docView = [self displayDocument:doc positioned:ViViewPositionTab];
			if (command.plus_command && docView) {
				ViTextView *text = (ViTextView *)[docView innerView];
				if (![text evalExString:command.plus_command])
					return [NSNumber numberWithBool:NO];
			}
		}
	}

	return error;
}

// FIXME: new, vnew, split and vsplit can all take a +excommand argument

- (id)ex_new:(ExCommand *)command
{
	return [self splitVertically:NO
                             andOpen:[self parseExFilename:command.arg]
                  orSwitchToDocument:nil] ? nil : [NSNumber numberWithBool:NO];
}

- (id)ex_vnew:(ExCommand *)command
{
	return [self splitVertically:YES
                             andOpen:[self parseExFilename:command.arg]
                  orSwitchToDocument:nil] ? nil : [NSNumber numberWithBool:NO];
}

- (id)ex_split:(ExCommand *)command
{
	return [self splitVertically:NO
                             andOpen:[self parseExFilename:command.arg]
                  orSwitchToDocument:[self currentDocument]] ? nil : [NSNumber numberWithBool:NO];
}

- (id)ex_vsplit:(ExCommand *)command
{
	return [self splitVertically:YES
                             andOpen:[self parseExFilename:command.arg]
                  orSwitchToDocument:[self currentDocument]] ? nil : [NSNumber numberWithBool:NO];
}

- (id)ex_buffer:(ExCommand *)command
{
	if (command.arg == nil)
		return nil;
		// return [ViError message:@"Missing buffer name"];

	NSMutableArray *matches = [NSMutableArray array];

	ViDocument *doc = nil;
	for (doc in [self documents]) {
		if ([doc fileURL] &&
		    [[[doc fileURL] absoluteString] rangeOfString:command.arg
							  options:NSCaseInsensitiveSearch].location != NSNotFound)
			[matches addObject:doc];
	}

	if ([matches count] == 0)
		return [ViError errorWithFormat:@"No matching buffer for %@", command.arg];
	else if ([matches count] > 1)
		return [ViError errorWithFormat:@"More than one match for %@", command.arg];

	NSView *view = [[self currentView] innerView];
	if ([view respondsToSelector:@selector(pushCurrentLocationOnJumpList)])
		[(ViTextView *)view pushCurrentLocationOnJumpList];

	doc = [matches objectAtIndex:0];
	ViViewPosition position = ViViewPositionDefault;

	if ([command.mapping.name hasPrefix:@"b"]) {
		if ([self currentDocument] == doc)
			return nil;
		position = ViViewPositionReplace;
	} else if ([command.mapping.name isEqualToString:@"vbuffer"])
		position = ViViewPositionSplitLeft;
	else if ([command.mapping.name isEqualToString:@"sbuffer"])
		position = ViViewPositionSplitAbove;

	[self displayDocument:doc positioned:position];

	return nil;
}

/* syntax: bd[elete] bufname */
- (id)ex_bdelete:(ExCommand *)command
{
	if (command.arg) {
		ViDocument *doc = nil;
		NSMutableSet *matches = [NSMutableSet set];
		for (doc in [self documents]) {
			if ([doc fileURL] &&
			    [[[doc fileURL] absoluteString] rangeOfString:command.arg
								  options:NSCaseInsensitiveSearch].location != NSNotFound)
				[matches addObject:doc];
		}

		if ([matches count] == 0)
			return [ViError errorWithFormat:@"No matching buffer for %@", command.arg];
		else if ([matches count] > 1)
			return [ViError errorWithFormat:@"More than one match for %@", command.arg];

		doc = [matches anyObject];
		if (command.force)
			[doc closeAndWindow:NO];
		else
			[[ViWindowController currentWindowController] closeDocument:doc andWindow:NO];
	} else {
		if ([self currentDocument] == nil)
			return [ViError message:@"No current document."];
		if (command.force)
			[[self currentDocument] closeAndWindow:NO];
		else
			[[ViWindowController currentWindowController] closeDocument:[self currentDocument] andWindow:NO];
	}
	return nil;
}

- (id)ex_set:(ExCommand *)command
{
	NSDictionary *variables = [NSDictionary dictionaryWithObjectsAndKeys:
		@"shiftwidth", @"sw",
		@"autoindent", @"ai",
		@"smartindent", @"si",
		@"expandtab", @"et",
		@"smartpair", @"smp",
		@"tabstop", @"ts",
		@"wrap", @"wrap",
		@"smarttab", @"sta",

		@"gdefault", @"gd",
		@"wrapscan", @"ws",
		@"showguide", @"sg",
		@"guidecolumn", @"gc",
		@"prefertabs", @"prefertabs",
		@"ignorecase", @"ic",
		@"smartcase", @"scs",
		@"number", @"nu",
		@"number", @"num",
		@"number", @"numb",
		@"relativenumber", @"rnu",
		@"autocollapse", @"ac",  // automatically collapses other documents in the symbol list
		@"hidetab", @"ht",  // hide tab bar for single tabs
		@"fontsize", @"fs",
		@"fontname", @"font",
		@"searchincr", @"searchincr",
		@"antialias", @"antialias",
		@"undostyle", @"undostyle",
		@"list", @"list",
		@"formatprg", @"fp",
		@"cursorline", @"cul",
		@"clipboard", @"cb",
		@"matchparen", @"matchparen",
		@"flashparen", @"flashparen",
		@"linebreak", @"lbr",
		@"blinktime", @"blinktime",
		@"blinkmode", @"blinkmode",
		nil];

	NSArray *booleans = [NSArray arrayWithObjects:
	    @"autoindent", @"expandtab", @"smartpair", @"ignorecase", @"smartcase", @"number",
	    @"relativenumber", @"autocollapse", @"hidetab", @"shjwguide", @"searchincr",
	    @"smartindent", @"wrap", @"antialias", @"list", @"smarttab", @"prefertabs",
	    @"cursorline", @"gdefault", @"wrapscan", @"clipboard", @"matchparen",
	    @"flashparen", @"linebreak",
	    nil];

	NSString *var;
	for (var in command.args) {
		NSUInteger equals = [var rangeOfString:@"="].location;
		NSUInteger qmark = [var rangeOfString:@"?"].location;
		if (equals == 0 || qmark == 0)
			return [ViError message:@"se[t] [option[=[value]]...] [nooption ...] [invoption ...] [option! ...] [option? ...] [all]"];

		BOOL turnoff = NO;
		BOOL toggle = NO;
		NSString *name;
		if (equals != NSNotFound)
			name = [var substringToIndex:equals];
		else if (qmark != NSNotFound)
			name = [var substringToIndex:qmark];
		else {
			name = var;

			if ([name hasPrefix:@"no"]) {
				name = [name substringFromIndex:2];
				turnoff = YES;
			} else if ([name hasPrefix:@"inv"]) {
				name = [name substringFromIndex:3];
				toggle = YES;
			} else if ([name hasSuffix:@"!"]) {
				name = [name substringToIndex:[name length] - 1];
				toggle = YES;
			}
		}

		if ([name isEqualToString:@"all"])
			return [ViError message:@"'set all' not implemented."];

		NSString *defaults_name = [variables objectForKey:name];
		if (defaults_name == nil && [[variables allValues] containsObject:name])
			defaults_name = name;

		if (defaults_name == nil)
			return [ViError errorWithFormat:@"set: no %@ option: 'set all' gives all option values.", name];

		if (qmark != NSNotFound) {
			if ([booleans containsObject:defaults_name]) {
				NSInteger val = [[NSUserDefaults standardUserDefaults] integerForKey:defaults_name];
				[command message:[NSString stringWithFormat:@"%@%@", val == NSOffState ? @"no" : @"", defaults_name]];
			} else {
				NSString *val = [[NSUserDefaults standardUserDefaults] stringForKey:defaults_name];
				[command message:[NSString stringWithFormat:@"%@=%@", defaults_name, val]];
			}
			continue;
		}

		if ([booleans containsObject:defaults_name]) {
			if (equals != NSNotFound)
				return [ViError errorWithFormat:@"set: [no]%@ option doesn't take a value", defaults_name];

			if (toggle)
				turnoff = [[NSUserDefaults standardUserDefaults] boolForKey:defaults_name];
			[[NSUserDefaults standardUserDefaults] setInteger:turnoff ? NSOffState : NSOnState forKey:defaults_name];
		} else {
			if (equals == NSNotFound) {
				NSString *val = [[NSUserDefaults standardUserDefaults] stringForKey:defaults_name];
				[command message:[NSString stringWithFormat:@"%@=%@", defaults_name, val]];
			} else {
				NSString *val = [var substringFromIndex:equals + 1];
				[[NSUserDefaults standardUserDefaults] setObject:val forKey:defaults_name];
			}
		}
	}

	return nil;
}

- (id)ex_export:(ExCommand *)command
{
	if (command.arg == nil)
		return nil;

	NSScanner *scan = [NSScanner scannerWithString:command.arg];
	NSString *variable, *value = nil;

	if (![scan scanUpToString:@"=" intoString:&variable] ||
	    ![scan scanString:@"=" intoString:nil])
		return [ViError message:@"Missing equal sign."];

	if (![scan isAtEnd])
		value = [[scan string] substringFromIndex:[scan scanLocation]];

	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSDictionary *curenv = [defs dictionaryForKey:@"environment"];
	NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:curenv];

	if (value)
		[env setObject:value forKey:variable];
	else
		[env removeObjectForKey:value];

	[defs setObject:env forKey:@"environment"];
	DEBUG(@"static environment is now %@", env);

	return nil;
}

- (id)ex_quit:(ExCommand *)command
{
	ViViewController *viewController = [self currentView];
	if ([tabView numberOfTabViewItems] > 1 || [[[[self currentView] tabController] views] count] > 1) {
		[self closeDocumentView:viewController
		       canCloseDocument:NO
			 canCloseWindow:NO];
	} else if (command.force) {
		ViDocument *doc;
		while ((doc = [_documents anyObject]) != nil) {
			if ([self documentOpenElsewhere:doc]) {
				[self unlistDocument:doc];
			} else {
				[doc closeAndWindow:YES];
			}
		}
		[[self window] close];
	} else {
		[[self window] performClose:nil];
	}

	// FIXME: quit/hide app if last window?
	return nil;
}

@end

