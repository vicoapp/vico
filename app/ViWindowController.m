#import "ViWindowController.h"
#import "PSMTabBarControl.h"
#import "ViDocument.h"
#import "ViDocumentView.h"
#import "ViDocumentTabController.h"
#import "ViProject.h"
#import "ProjectDelegate.h"
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

static NSMutableArray		*windowControllers = nil;
static ViWindowController	*currentWindowController = nil;

@interface ViWindowController ()
- (void)updateJumplistNavigator;
- (void)didSelectDocument:(ViDocument *)document;
- (void)didSelectViewController:(id<ViViewController>)viewController;
- (ViDocumentTabController *)selectedTabController;
- (void)closeDocumentView:(id<ViViewController>)viewController
         canCloseDocument:(BOOL)canCloseDocument;
@end


#pragma mark -
@implementation ViWindowController

@synthesize documents;
@synthesize project;
@synthesize environment;
@synthesize proxy;
@synthesize explorer = projectDelegate;
@synthesize jumpList, jumping;
@synthesize tagStack, tagsDatabase;
@synthesize previousDocument;

+ (ViWindowController *)currentWindowController
{
	if (currentWindowController == nil)
		[[ViWindowController alloc] init];
	return currentWindowController;
}

+ (NSWindow *)currentMainWindow
{
	if (currentWindowController)
		return [currentWindowController window];
	else if ([windowControllers count] > 0)
		return [[windowControllers objectAtIndex:0] window];
	else
		return nil;
}

- (id)init
{
	self = [super initWithWindowNibName:@"ViDocumentWindow"];
	if (self) {
		isLoaded = NO;
		if (windowControllers == nil)
			windowControllers = [NSMutableArray array];
		[windowControllers addObject:self];
		currentWindowController = self;
		documents = [NSMutableArray array];
		jumpList = [[ViJumpList alloc] init];
		[jumpList setDelegate:self];
		parser = [[ViParser alloc] initWithDefaultMap:[ViMap normalMap]];
		proxy = [[ViScriptProxy alloc] initWithObject:self];
		tagStack = [[ViTagStack alloc] init];
	}

	return self;
}

- (ViTagsDatabase *)tagsDatabase
{
	if (tagsDatabase == nil)
		tagsDatabase = [[ViTagsDatabase alloc] initWithBaseURL:[environment baseURL]];

	return tagsDatabase;
}

- (ViParser *)parser
{
	return parser;
}

- (void)getMoreBundles:(id)sender
{
	[[ViPreferencesController sharedPreferences] performSelector:@selector(showItem:)
							  withObject:@"BundlesItem" afterDelay:0.01];
}

- (void)windowDidResize:(NSNotification *)notification
{
	[[self window] saveFrameUsingName:@"MainDocumentWindow"];
}

- (void)tearDownBundleMenu:(NSNotification *)notification
{
	NSMenu *menu = (NSMenu *)[notification object];

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
	if (![[self currentView] isKindOfClass:[ViDocumentView class]])
		return;
	ViDocumentView *docView = [self currentView];
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
	[tabBar setCanCloseOnlyTab:YES];
	[tabBar setHideForSingleTab:[[NSUserDefaults standardUserDefaults] boolForKey:@"hidetab"]];
	// FIXME: add KVC observer for the 'hidetab' option
	[tabBar setPartnerView:splitView];
	[tabBar setShowAddTabButton:YES];
	[tabBar setAllowsDragBetweenWindows:NO]; // XXX: Must update for this to work without NSTabview

	[[self window] setDelegate:self];
	[[self window] setFrameUsingName:@"MainDocumentWindow"];

	[splitView addSubview:explorerView positioned:NSWindowBelow relativeTo:mainView];
	[splitView addSubview:symbolsView];

	isLoaded = YES;
	if (initialDocument) {
		[self addNewTab:initialDocument];
                initialDocument = nil;
	}

	[[self window] bind:@"title" toObject:self withKeyPath:@"currentView.title" options:nil];

	[[self window] makeKeyAndOrderFront:self];
	[symbolsView setSourceHighlight:YES];
	[explorerView setSourceHighlight:YES];
	[symbolsView setNeedsDisplay:YES];
	[explorerView setNeedsDisplay:YES];

	NSRect frame = [splitView frame];
	[splitView setPosition:NSWidth(frame) ofDividerAtIndex:1];
	[splitView setAutosaveName:@"ProjectSymbolSplitView"];

	if ([self project] != nil) {
		[environment setBaseURL:[[self project] initialURL]];
		[projectDelegate performSelector:@selector(browseURL:) withObject:[[self project] initialURL] afterDelay:0.0];
		/* This makes repeated open requests for the same URL always open a new window.
		 * With this commented, the "project" is already opened, and no new window will be created.
		[[self project] close];
		project = nil;
		*/
	} else if ([projectDelegate explorerIsOpen])
		[projectDelegate performSelector:@selector(browseURL:) withObject:[environment baseURL] afterDelay:0.0];

	[self updateJumplistNavigator];

	[parser setNviStyleUndo:[[[NSUserDefaults standardUserDefaults] stringForKey:@"undostyle"] isEqualToString:@"nvi"]];
	[[NSUserDefaults standardUserDefaults] addObserver:self
						forKeyPath:@"undostyle"
						   options:NSKeyValueObservingOptionNew
						   context:NULL];
}

- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)anObject
{
	if ([anObject isKindOfClass:[ExTextField class]]) {
		if (viFieldEditor == nil) {
			ViTextStorage *textStorage = [[ViTextStorage alloc] init];
			ViLayoutManager *layoutManager = [[ViLayoutManager alloc] init];
			[textStorage addLayoutManager:layoutManager];
			NSTextContainer *container = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(100, 10)];
			[layoutManager addTextContainer:container];
			NSRect frame = NSMakeRect(0, 0, 100, 10);
			viFieldEditor = [[ViTextView alloc] initWithFrame:frame textContainer:container];
			ViParser *fieldParser = [[ViParser alloc] initWithDefaultMap:[ViMap mapWithName:@"exCommandMap"]];
			[viFieldEditor initWithDocument:nil viParser:fieldParser];
			[viFieldEditor setFieldEditor:YES];
			[viFieldEditor setInsertMode:nil];
		}
		return viFieldEditor;
	}
	return nil;
}

- (void)browseURL:(NSURL *)url
{
	[projectDelegate browseURL:url];
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
		[parser setNviStyleUndo:[newStyle isEqualToString:@"nvi"]];
	}
}

- (void)addDocument:(ViDocument *)document
{
	if ([documents containsObject:document])
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

	[documents addObject:document];

	/* Update symbol table. */
	[symbolController filterSymbols];
	[document addObserver:symbolController forKeyPath:@"symbols" options:0 context:NULL];
}

/* Create a new document tab.
 */
- (void)createTabWithViewController:(id<ViViewController>)viewController
{
	ViDocumentTabController *tabController = [[ViDocumentTabController alloc] initWithViewController:viewController];

	NSTabViewItem *tabItem = [[NSTabViewItem alloc] initWithIdentifier:tabController];
	[tabItem bind:@"label" toObject:tabController withKeyPath:@"selectedView.title" options:nil];
	[tabItem setView:[tabController view]];
	[tabView addTabViewItem:tabItem];
	[tabView selectTabViewItem:tabItem];
	[self focusEditor];
}

- (ViDocumentView *)createTabForDocument:(ViDocument *)document
{
	ViDocumentView *docView = [document makeView];
	[self createTabWithViewController:docView];
	return docView;
}

/* Called by a new ViDocument in its makeWindowControllers method.
 */
- (void)addNewTab:(ViDocument *)document
{
	if (!isLoaded) {
		/* Defer until NIB is loaded. */
		initialDocument = document;
		return;
	}

	/*
	 * If current document is untitled and unchanged and the rightmost tab, replace it.
	 */
	ViDocument *closeThisDocument = nil;
	ViDocumentTabController *lastTabController = [[[tabBar representedTabViewItems] lastObject] identifier];
	if ([self currentDocument] != nil &&
	    [[self currentDocument] fileURL] == nil &&
	    [document fileURL] != nil &&
	    ![[self currentDocument] isDocumentEdited] &&
	    [[lastTabController views] count] == 1 &&
	    [self currentDocument] == [[[lastTabController views] objectAtIndex:0] document]) {
		[tabBar disableAnimations];
		closeThisDocument = [self currentDocument];
	}

	[self addDocument:document];
	[self createTabForDocument:document];

	if (closeThisDocument) {
		[closeThisDocument close];
		[tabBar enableAnimations];
	}
}

- (void)documentChangedAlertDidEnd:(NSAlert *)alert
                        returnCode:(NSInteger)returnCode
                       contextInfo:(void *)contextInfo
{
	ViDocument *document = contextInfo;

	if (returnCode == NSAlertSecondButtonReturn) {
		NSError *error = nil;
		[document revertToContentsOfURL:[document fileURL]
					 ofType:[document fileType]
					  error:&error];
		if (error) {
			[[alert window] orderOut:self];
			NSAlert *revertAlert = [NSAlert alertWithError:error];
			[revertAlert beginSheetModalForWindow:[self window]
					        modalDelegate:nil
					       didEndSelector:nil
						  contextInfo:nil];
			[document updateChangeCount:NSChangeReadOtherContents];
		}
	}
}

- (void)checkDocumentChanged:(ViDocument *)document
{
	if (document == nil || [document isTemporary])
		return;

	if ([[document fileURL] isFileURL]) {
		NSError *error = nil;
		NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[[document fileURL] path] error:&error];
		if (error) {
			NSAlert *alert = [NSAlert alertWithError:error];
			[alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
			[document updateChangeCount:NSChangeReadOtherContents];
			document.isTemporary = YES;
			return;
		}

		NSDate *modificationDate = [attributes fileModificationDate];
		if ([[document fileModificationDate] compare:modificationDate] == NSOrderedAscending) {
			[document updateChangeCount:NSChangeReadOtherContents];

			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText:@"This document’s file has been changed by another application since you opened or saved it."];
			[alert setInformativeText:@"Do you want to keep this version or revert to the document on disk?"];
			[alert addButtonWithTitle:@"Keep open version"];
			[alert addButtonWithTitle:@"Revert"];
			[alert beginSheetModalForWindow:[self window]
					  modalDelegate:self
					 didEndSelector:@selector(documentChangedAlertDidEnd:returnCode:contextInfo:)
					    contextInfo:document];
		}
	}
}

- (void)focusEditorDelayed:(id)sender
{
	if ([self currentView])
		[[self window] makeFirstResponder:[[self currentView] innerView]];
}

- (void)focusEditor
{
	[self performSelector:@selector(focusEditorDelayed:)
	           withObject:nil
	           afterDelay:0.0];
}

- (ViTagStack *)sharedTagStack
{
	if (tagStack == nil)
		tagStack = [[ViTagStack alloc] init];
	return tagStack;
}

- (void)windowDidBecomeMain:(NSNotification *)aNotification
{
	currentWindowController = self;
	[self checkDocumentChanged:[self currentDocument]];
}

- (ViDocument *)currentDocument
{
	id<ViViewController> viewController = [self currentView];
	if ([viewController isKindOfClass:[ViDocumentView class]])
		return [(ViDocumentView *)viewController document];
	return nil;
}

- (void)caretChanged:(NSNotification *)notification
{
	ViTextView *textView = [notification object];
	if (textView == [[self currentView] innerView])
		[symbolController updateSelectedSymbolForLocation:[textView caret]];
}

- (void)showMessage:(NSString *)string
{
	[messageField setStringValue:string];
}

- (void)message:(NSString *)fmt arguments:(va_list)ap
{
	[messageField setStringValue:[[NSString alloc] initWithFormat:fmt arguments:ap]];
}

- (void)message:(NSString *)fmt, ...
{
	va_list ap;
	va_start(ap, fmt);
	[self message:fmt arguments:ap];
	va_end(ap);
}

#pragma mark -
#pragma mark Document closing

- (void)documentController:(NSDocumentController *)docController
               didCloseAll:(BOOL)didCloseAll
               contextInfo:(void *)contextInfo
{
	if (didCloseAll)
		[[self window] close];
}

- (BOOL)windowShouldClose:(id)window
{
	[[self currentDocument] close];
	if ([documents count] == 0)
		return YES;

	NSMutableSet *set = [[NSMutableSet alloc] init];
	for (ViDocument *doc in [[window windowController] documents])
		[set addObject:doc];

	[[NSDocumentController sharedDocumentController] closeAllDocumentsInSet:set
								   withDelegate:self
							    didCloseAllSelector:@selector(documentController:didCloseAll:contextInfo:)
								    contextInfo:NULL];
	return NO;
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	if (currentWindowController == self)
		currentWindowController = nil;
	[[self project] close];
	[windowControllers removeObject:self];
	[tabBar setDelegate:nil];
}

- (id<ViViewController>)currentView;
{
	return currentView;
}

- (void)setCurrentView:(id<ViViewController>)viewController
{
	if ([currentView isKindOfClass:[ViDocumentView class]])
		previousDocumentView = currentView;
	currentView = viewController;
}

- (void)closeTabController:(ViDocumentTabController *)tabController
{
	NSInteger ndx = [tabView indexOfTabViewItemWithIdentifier:tabController];
	if (ndx != NSNotFound) {
		NSTabViewItem *item = [tabView tabViewItemAtIndex:ndx];
		[tabView removeTabViewItem:item];
		[self tabView:tabView didCloseTabViewItem:item];

		while ([[tabController views] count] > 0) {
			id<ViViewController> viewController;
			viewController  = [[tabController views] objectAtIndex:0];
			if ([viewController isKindOfClass:[ViDocumentView class]]) {
				ViDocumentView *docView = viewController;
				ViDocument *doc = [docView document];
				if ([[doc views] count] == 1) {
					[doc close];
					continue;
				}
			}
			[[viewController tabController] closeView:viewController];
		}
	}
}

- (void)document:(NSDocument *)doc
     shouldClose:(BOOL)shouldClose
     contextInfo:(void *)contextInfo
{
	if (!shouldClose)
		return;

	[doc close];
}

/*
 * Called by the ViDocumentController when user presses command-w.
 *
 * Close the current view. If this is the last view of the enclosed document,
 * close the document too.
 *
 * If this view is the last in a tab, the tab is closed.
 *
 * If the tab is the last one, either:
 *  a) if there are no more open documents, close the window.
 *  b) bring in one of the other hidden documents into this view. (??)
 */
- (void)closeCurrentView
{
	id<ViViewController> viewController = [self currentView];

	if ([viewController isKindOfClass:[ViDocumentView class]]) {
		ViDocument *doc = [(ViDocumentView *)viewController document];
		if ([[doc views] count] == 1) {
			// closing the last view, close the document
			[doc canCloseDocumentWithDelegate:self
			              shouldCloseSelector:@selector(document:shouldClose:contextInfo:)
			                      contextInfo:viewController];
			return;
		}
	}

	[self closeDocumentView:viewController canCloseDocument:YES];
}

/*
 * Close the current view (but not the document!) unless this is
 * the last view in the window.
 * Called by C-w c.
 */
- (BOOL)closeCurrentViewUnlessLast
{
	ViDocumentView *docView = [self currentView];
	if ([tabView numberOfTabViewItems] > 1 || [[[docView tabController] views] count] > 1) {
		[self closeDocumentView:docView canCloseDocument:NO];
		return YES;
	}
	return NO;
}

- (void)closeDocumentView:(id<ViViewController>)viewController
         canCloseDocument:(BOOL)canCloseDocument
{
	if (viewController == nil)
		[[self window] close];

	if (viewController == currentView)
		[self setCurrentView:nil];

	[[viewController tabController] closeView:viewController];

	/* If this was the last view of the document, close the document too. */
	if (canCloseDocument && [viewController isKindOfClass:[ViDocumentView class]]) {
		ViDocument *doc = [(ViDocumentView *)viewController document];
		if ([[doc views] count] == 0)
			[doc close];
	}

	/* If this was the last view in the tab, close the tab too. */
	ViDocumentTabController *tabController = [viewController tabController];
	if ([[tabController views] count] == 0) {
		[self closeTabController:tabController];

		if ([tabView numberOfTabViewItems] == 0) {
			if ([documents count] > 0)
				[self selectDocument:[documents objectAtIndex:0]];
			else if (![projectDelegate explorerIsOpen])
				[[self window] close];
		}
	} else if (tabController == [self selectedTabController]) {
		// Select another document view.
		[self selectDocumentView:tabController.selectedView];
	}
}

/*
 * Called by the document when it closes.
 * Removes all views of the document.
 */
- (void)closeDocument:(ViDocument *)document
{
	// Close all views of the document
	ViDocumentView *docView;
	while ((docView = [[document views] anyObject]) != nil)
		[self closeDocumentView:docView canCloseDocument:YES];

	NSInteger ndx = [[openFilesButton menu] indexOfItemWithRepresentedObject:document];
	if (ndx != -1)
		[[openFilesButton menu] removeItemAtIndex:ndx];

	[documents removeObject:document];
}

- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	ViDocumentTabController *tabController = [tabViewItem identifier];
	[self selectDocumentView:tabController.selectedView];
}

- (void)documentController:(NSDocumentController *)docController
               didCloseAll:(BOOL)didCloseAll
             tabController:(void *)tabController
{
	if (didCloseAll)
		[self closeTabController:tabController];
}

- (BOOL)tabView:(NSTabView *)aTabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
	ViDocumentTabController *tabController = [tabViewItem identifier];

	/*
	 * Directly close all views for documents that either
	 *  a) have another view in another tab, or
	 *  b) is not modified
	 *
	 * For any document that can't directly be closed, ask the user.
	 */

	NSMutableSet *set = [[NSMutableSet alloc] init];

	id<ViViewController> viewController;
	for (viewController in [tabController views]) {
		if ([viewController isKindOfClass:[ViDocument class]]) {
			ViDocumentView *docView;
			if ([set containsObject:[docView document]])
				continue;
			if (![[docView document] isDocumentEdited])
				continue;

			ViDocumentView *otherDocView;
			for (otherDocView in [[docView document] views])
				if ([otherDocView tabController] != tabController)
					break;
			if (otherDocView != nil)
				continue;

			[set addObject:[docView document]];
		}
	}

	[[NSDocumentController sharedDocumentController] closeAllDocumentsInSet:set
								   withDelegate:self
							    didCloseAllSelector:@selector(documentController:didCloseAll:tabController:)
								    contextInfo:tabController];

	return NO;
}

- (void)tabView:(NSTabView *)aTabView willCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
}

- (void)tabView:(NSTabView *)aTabView didCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
	// FIXME: check if there are hidden documents and display them in that case
	if ([tabView numberOfTabViewItems] == 0) {
#if 0
		if ([self project] == nil)
			[[self window] close];
		else
			[self synchronizeWindowTitleWithDocumentName];
#endif
	}
}

#pragma mark -
#pragma mark Switching documents

- (void)firstResponderChanged:(NSNotification *)notification
{
	id<ViViewController> viewController = [self viewControllerForView:[notification object]];
	if (viewController) {
		if (parser.partial) {
			[self message:@"Vi command interrupted."];
			[parser reset];
		}
		[self didSelectViewController:viewController];
	}
}

- (void)didSelectDocument:(ViDocument *)document
{
	if (document == nil)
		return;

	// XXX: currentView is the *previously* current view
	id<ViViewController> viewController = [self currentView];
	if ([viewController isKindOfClass:[ViDocumentView class]]) {
		if ([(ViDocumentView *)viewController document] == document)
			return;
	}

	[[self document] removeWindowController:self];
	[document addWindowController:self];
	[self setDocument:document];

	NSInteger ndx = [[openFilesButton menu] indexOfItemWithRepresentedObject:document];
	if (ndx != -1)
		[openFilesButton selectItemAtIndex:ndx];

	// update symbol list
	[symbolController didSelectDocument:document];

	[self checkDocumentChanged:document];
}

- (void)didSelectViewController:(id<ViViewController>)viewController
{
	if (viewController == [self currentView])
		return;

	/* Update the previous document pointer. */
	id<ViViewController> prevView = [self currentView];
	if ([prevView isKindOfClass:[ViDocumentView class]]) {
		previousDocument = [(ViDocumentView *)prevView document];
	}

	if ([viewController isKindOfClass:[ViDocumentView class]]) {
		ViDocumentView *docView = viewController;
		if (!jumping)
			[[docView textView] pushCurrentLocationOnJumpList];
		[self didSelectDocument:[docView document]];
		[symbolController updateSelectedSymbolForLocation:[[docView textView] caret]];
	}
	[[viewController tabController] setSelectedView:viewController];

	[self setCurrentView:viewController];
}

/*
 * Selects the tab holding the given document view and focuses the view.
 */
- (id<ViViewController>)selectDocumentView:(id<ViViewController>)viewController
{
	ViDocumentTabController *tabController = [viewController tabController];

	NSInteger ndx = [tabView indexOfTabViewItemWithIdentifier:tabController];
	if (ndx == NSNotFound)
		return nil;

	NSTabViewItem *item = [tabView tabViewItemAtIndex:ndx];
	[tabView selectTabViewItem:item];

	// Focus the text view
	[[self window] makeFirstResponder:[viewController innerView]];

	return viewController;
}

/*
 * Returns the most appropriate view for the given document.
 * Returns nil if no view of the document is currently open.
 */
- (ViDocumentView *)viewForDocument:(ViDocument *)document
{
	if (!isLoaded || document == nil)
		return nil;

	ViDocumentView *docView = nil;
	id<ViViewController> viewController = [self currentView];

	/* Check if the current view contains the document. */
	if ([viewController isKindOfClass:[ViDocumentView class]]) {
		docView = viewController;
		if ([docView document] == document)
			return viewController;
	}

	/* Check if current tab has a view of the document. */
	ViDocumentTabController *tabController = [self selectedTabController];
	for (viewController in [tabController views])
		if ([viewController isKindOfClass:[ViDocumentView class]] &&
		    [[(ViDocumentView *)viewController document] isEqual:document])
			return viewController;

	/* Check if the previous document view holds the document. */
	if ([previousDocumentView document] == document) {
		/* Is it still visible? */
		if ([[document views] containsObject:previousDocumentView])
			return previousDocumentView;
	}

	/* Select any existing view of the document. */
	if ([[document views] count] > 0) {
		docView = [[document views] anyObject];
		/*
		 * If the tab with the document view contains more views
		 * of the same document, prefer the selected view in the
		 * (randomly) selected tab controller.
		 */
		id<ViViewController> selView = [[docView tabController] selectedView];
		if ([selView isKindOfClass:[ViDocumentView class]] &&
		    [(ViDocumentView *)selView document] == document)
			return [self selectDocumentView:selView];
		return [self selectDocumentView:docView];
	}

	/* No open view for the given document. */
	return nil;
}

/*
 * Selects the most appropriate view for the given document.
 * Will change current tab if no view of the document is visible in the current tab.
 *
 * What if the document is not visible in _any_ view? Create a new
 * tab? Change the current view to show the given document?
 */
- (ViDocumentView *)selectDocument:(ViDocument *)document
{
	if (!isLoaded || document == nil)
		return nil;

	ViDocumentView *docView = [self viewForDocument:document];
	if (docView)
		return [self selectDocumentView:docView];

	/* No view exists of the document, create a new tab. */
	docView = [self createTabForDocument:document];
	return [self selectDocumentView:docView];
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

- (void)switchToDocument:(ViDocument *)doc
{
	ViDocumentTabController *tabController = [self selectedTabController];
	id<ViViewController> viewController = [tabController replaceView:[self currentView]
							    withDocument:doc];
	[self selectDocumentView:viewController];
}

- (void)switchToLastDocument
{
	[self switchToDocument:previousDocument];
}

- (void)selectLastDocument
{
	[self selectDocument:previousDocument];
}

- (ViDocumentTabController *)selectedTabController
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
		[self switchToDocument:doc];
}

- (ViDocument *)documentForURL:(NSURL *)url
{
	ViDocument *doc;
	for (doc in documents)
		if ([url isEqual:[doc fileURL]])
			return doc;
	return nil;
}

- (BOOL)gotoURL:(NSURL *)url
           line:(NSUInteger)line
         column:(NSUInteger)column
           view:(ViDocumentView *)docView
{
	ViDocument *document = [self documentForURL:url];
	if (document == nil) {
		NSError *error = nil;
		ViDocumentController *ctrl = [NSDocumentController sharedDocumentController];
		document = [ctrl openDocumentWithContentsOfURL:url display:YES error:&error];
		if (error) {
			[NSApp presentError:error];	
			return NO;
		}
	}

	if (docView == nil)
		docView = [self selectDocument:document];
	else
		[self selectDocumentView:docView];

	if (line > 0)
		[[docView textView] gotoLine:line column:column];

	return YES;
}

- (BOOL)gotoURL:(NSURL *)url line:(NSUInteger)line column:(NSUInteger)column
{
	return [self gotoURL:url line:line column:column view:nil];
}

- (BOOL)gotoURL:(NSURL *)url lineNumber:(NSNumber *)lineNumber
{
	return [self gotoURL:url line:[lineNumber unsignedIntegerValue] column:0];
}

- (BOOL)gotoURL:(NSURL *)url
{
	return [self gotoURL:url line:0 column:0];
}

#pragma mark -
#pragma mark View Splitting

- (IBAction)splitViewHorizontally:(id)sender
{
	id<ViViewController> viewController = [self currentView];
	if (viewController == nil)
		return;

	// Only document views support splitting (?)
	if ([viewController isKindOfClass:[ViDocumentView class]]) {
		ViDocumentTabController *tabController = [viewController tabController];
		[tabController splitView:viewController vertically:NO];
		[self selectDocumentView:viewController];
	}
}

- (IBAction)splitViewVertically:(id)sender
{
	id<ViViewController> viewController = [self currentView];
	if (viewController == nil)
		return;

	// Only document views support splitting (?)
	if ([viewController isKindOfClass:[ViDocumentView class]]) {
		ViDocumentTabController *tabController = [viewController tabController];
		[tabController splitView:viewController vertically:YES];
		[self selectDocumentView:viewController];
	}
}

- (id<ViViewController>)viewControllerForView:(NSView *)aView
{
	if (aView == nil)
		return nil;

	NSArray *tabs = [tabBar representedTabViewItems];
	for (NSTabViewItem *item in tabs) {
		id<ViViewController> viewController = [[item identifier] viewControllerForView:aView];
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
	id<ViViewController> viewController = [self currentView];
	if (viewController == nil)
		return NO;

	ViDocumentTabController *tabController = [viewController tabController];
	[tabController normalizeAllViews];
	return YES;
}

- (BOOL)closeOtherViews
{
	id<ViViewController> viewController = [self currentView];
	if (viewController == nil)
		return NO;

	ViDocumentTabController *tabController = [viewController tabController];
	if ([[tabController views] count] == 1) {
		[self message:@"Already only one window"];
		return NO;
	}
	[tabController closeViewsOtherThan:viewController];
	return YES;
}

- (BOOL)moveCurrentViewToNewTab
{
	id<ViViewController> viewController = [self currentView];
	if (viewController == nil)
		return NO;

	ViDocumentTabController *tabController = [viewController tabController];
	if ([[tabController views] count] == 1) {
		[self message:@"Already only one window"];
		return NO;
	}

	[tabController closeView:viewController];
	[self createTabWithViewController:viewController];
	return YES;
}

- (IBAction)moveCurrentViewToNewTabAction:(id)sender
{
	[self moveCurrentViewToNewTab];
}

- (BOOL)selectViewAtPosition:(ViViewOrderingMode)position relativeTo:(id)aView
{
	id<ViViewController> viewController, otherViewController;
	if ([aView conformsToProtocol:@protocol(ViViewController)])
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

- (ViDocument *)splitVertically:(BOOL)isVertical
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
				       relativeTo:[environment baseURL]
					    error:&err];
		if (url && !err)
			doc = [ctrl openDocumentWithContentsOfURL:filenameOrURL
							  display:NO
							    error:&err];
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
		[doc addWindowController:self];
		[self addDocument:doc];

		id<ViViewController> viewController = [self currentView];
		ViDocumentTabController *tabController = [viewController tabController];
		ViDocumentView *newDocView = nil;
		if (allowReusedView && !newDoc) {
			/* Check if the tab already has a view for this document. */
			for (id<ViViewController> v in tabController.views)
				if ([v isKindOfClass:[ViDocumentView class]] &&
				    [(ViDocumentView *)v document] == doc) {
					newDocView = v;
					break;
				}
		}
		if (newDocView == nil)
			newDocView = [tabController splitView:viewController
						     withView:[doc makeView]
						   vertically:isVertical];
		[self selectDocumentView:newDocView];

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

- (ViDocument *)splitVertically:(BOOL)isVertical
                        andOpen:(id)filenameOrURL
             orSwitchToDocument:(ViDocument *)doc
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
	if (sender == splitView)
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
	if (sender == splitView)
	{
		// collapse both side views, but not the edit view
		if (subview == explorerView || subview == symbolsView)
			return YES;
	}
	return NO;
}

- (void)splitView:(id)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	if (sender != splitView)
		return;

	NSUInteger nsubviews = [[sender subviews] count];
	if (nsubviews < 2) {
		// the side views have not been added yet
		[sender adjustSubviews];
		return;
	}

	NSRect newFrame = [sender frame];
	float dividerThickness = [sender dividerThickness];

	NSInteger explorerWidth = 0;
	if ([sender isSubviewCollapsed:explorerView])
		explorerWidth = 0;
	else
		explorerWidth = [explorerView frame].size.width;

	NSRect symbolsFrame = [symbolsView frame];
	NSInteger symbolsWidth = symbolsFrame.size.width;
	if ([sender isSubviewCollapsed:symbolsView])
		symbolsWidth = 0;

	/* Keep the symbol sidebar in constant width. */
	NSRect mainFrame = [mainView frame];
	mainFrame.size.width = newFrame.size.width - (explorerWidth + symbolsWidth + (nsubviews-2)*dividerThickness);
	mainFrame.size.height = newFrame.size.height;

	[mainView setFrame:mainFrame];
	[sender adjustSubviews];
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
	if (leftView == explorerView)
		resizeRect = [projectResizeView frame];
	else if (rightView == symbolsView) {
		resizeRect = [symbolsResizeView frame];
		resizeRect.origin = [sender convertPoint:resizeRect.origin
					        fromView:symbolsResizeView];
	} else
		return NSZeroRect;

	resizeRect.origin.y = NSHeight(frame) - NSHeight(resizeRect);
	return resizeRect;
}

#pragma mark -
#pragma mark Symbol List

- (void)gotoSymbol:(ViSymbol *)aSymbol inView:(ViDocumentView *)docView
{
	NSRange range = aSymbol.range;
	ViTextView *textView = [docView textView];
	[textView setCaret:range.location];
	[textView scrollRangeToVisible:range];
	[[textView nextRunloop] showFindIndicatorForRange:range];
}

- (void)gotoSymbol:(ViSymbol *)aSymbol
{
	id<ViViewController> viewController = [self currentView];
	if ([viewController isKindOfClass:[ViDocumentView class]])
		[[(ViDocumentView *)viewController textView] pushCurrentLocationOnJumpList];

	/* XXX: prevent pushing an extraneous jump on the list. */
	jumping = YES;
	ViDocumentView *docView = [self selectDocument:aSymbol.document];
	jumping = NO;

	[self gotoSymbol:aSymbol inView:docView];
}

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
	ViRegexp *rx = [[ViRegexp alloc] initWithString:pattern
						options:ONIG_OPTION_IGNORECASE];

	NSMutableArray *syms = [NSMutableArray array];
	for (ViDocument *doc in documents)
		for (ViSymbol *s in doc.symbols)
			if ([rx matchInString:s.symbol])
				[syms addObject:s];

	return syms;
}

#pragma mark -

- (IBAction)searchFiles:(id)sender
{
	[projectDelegate searchFiles:sender];
}

- (IBAction)focusExplorer:(id)sender
{
	[projectDelegate focusExplorer:sender];
}

- (IBAction)toggleExplorer:(id)sender
{
	[projectDelegate toggleExplorer:sender];
}

#pragma mark -
#pragma mark Jumplist navigation

- (IBAction)navigateJumplist:(id)sender
{
	NSURL *url, **urlPtr = nil;
	NSUInteger line, *linePtr = NULL, column, *columnPtr = NULL;
	NSView **viewPtr = NULL;

	id<ViViewController> viewController = [self currentView];
	if ([viewController isKindOfClass:[ViDocumentView class]]) {
		ViTextView *tv = [(ViDocumentView *)viewController textView];
		if (tv == nil)
			return;
		url = [[self document] fileURL];
		line = [[tv textStorage] lineNumberAtLocation:[tv caret]];
		column = [[tv textStorage] columnAtLocation:[tv caret]];
		urlPtr = &url;
		linePtr = &line;
		columnPtr = &column;
		viewPtr = &tv;
	}

	if ([sender selectedSegment] == 0)
		[jumpList backwardToURL:urlPtr line:linePtr column:columnPtr view:viewPtr];
	else
		[jumpList forwardToURL:NULL line:NULL column:NULL view:NULL];
}

- (void)updateJumplistNavigator
{
	[jumplistNavigator setEnabled:![jumpList atEnd] forSegment:1];
	[jumplistNavigator setEnabled:![jumpList atBeginning] forSegment:0];
}

- (void)jumpList:(ViJumpList *)aJumpList added:(ViJump *)jump
{
	[self updateJumplistNavigator];
}

- (void)jumpList:(ViJumpList *)aJumpList goto:(ViJump *)jump
{
	/* XXX: Set a flag telling didSelectDocument: that we're currently navigating the jump list.
	 * This prevents us from pushing an extraneous jump on the list.
	 */
	jumping = YES;
	id<ViViewController> viewController = nil;
	if (jump.view)
		viewController = [self viewControllerForView:jump.view];
	[self gotoURL:jump.url line:jump.line column:jump.column view:viewController];
	jumping = NO;

	ViTextView *tv = [(ViDocumentView *)[self currentView] textView];
	[[tv nextRunloop] showFindIndicatorForRange:NSMakeRange(tv.caret, 1)];
	[self updateJumplistNavigator];
}

#pragma mark -
#pragma mark Vi actions

- (BOOL)increase_fontsize:(ViCommand *)command
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSInteger fs;
	NSInteger delta = 1;
	if ([command.mapping.parameter respondsToSelector:@selector(integerValue)])
		delta = [command.mapping.parameter integerValue];
	if (delta == 0)
		delta = 1;
	if (command.count == 0)
		fs = [defs integerForKey:@"fontsize"] + delta;
	else
		fs = command.count;
	if (fs <= 1)
		return NO;
	[defs setInteger:fs forKey:@"fontsize"];
	return YES;
}

- (BOOL)window_left:(ViCommand *)command
{
	return [self selectViewAtPosition:ViViewLeft relativeTo:currentView];
}

- (BOOL)window_down:(ViCommand *)command
{
	return [self selectViewAtPosition:ViViewDown relativeTo:currentView];
}

- (BOOL)window_up:(ViCommand *)command
{
	return [self selectViewAtPosition:ViViewUp relativeTo:currentView];
}

- (BOOL)window_right:(ViCommand *)command
{
	return [self selectViewAtPosition:ViViewRight relativeTo:currentView];
}

- (BOOL)window_close:(ViCommand *)command
{
	return [environment ex_close:nil];
}

- (BOOL)window_split:(ViCommand *)command
{
	return [environment ex_split:nil];
}

- (BOOL)window_vsplit:(ViCommand *)command
{
	return [environment ex_vsplit:nil];
}

- (BOOL)window_new:(ViCommand *)command
{
	return [environment ex_new:nil];
}

- (BOOL)window_totab:(ViCommand *)command
{
	return [self moveCurrentViewToNewTab];
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
	[self selectLastDocument];
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

@end

