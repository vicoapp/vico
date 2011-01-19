#import "ViWindowController.h"
#import "PSMTabBarControl.h"
#import "ViDocument.h"
#import "ViDocumentView.h"
#import "ViDocumentTabController.h"
#import "ViProject.h"
#import "ProjectDelegate.h"
#import "ViSymbol.h"
#import "ViSeparatorCell.h"
#import "ViJumpList.h"
#import "ViThemeStore.h"
#import "ViLanguageStore.h"
#import "ViDocumentController.h"
#import "ViPreferencesController.h"
#import "MHTextIconCell.h"
#import "ViAppController.h"
#import "NSTextStorage-additions.h"

static NSMutableArray		*windowControllers = nil;
static NSWindowController	*currentWindowController = nil;

@interface ViWindowController ()
- (ViDocument *)documentForURL:(NSURL *)url;
- (void)updateJumplistNavigator;
- (void)didSelectDocument:(ViDocument *)document;
- (void)didSelectDocumentView:(ViDocumentView *)docView;
- (ViDocumentTabController *)selectedTabController;
- (ViDocumentView *)currentView;
- (void)closeDocumentView:(ViDocumentView *)docView;
@end


#pragma mark -
@implementation ViWindowController

@synthesize documents;
@synthesize project;
@synthesize environment;

+ (id)currentWindowController
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
		[self setShouldCascadeWindows:NO];
		isLoaded = NO;
		if (windowControllers == nil)
			windowControllers = [[NSMutableArray alloc] init];
		[windowControllers addObject:self];
		currentWindowController = self;
		documents = [[NSMutableArray alloc] init];
		symbolFilterCache = [[NSMutableDictionary alloc] init];
		jumpList = [[ViJumpList alloc] init];
		[jumpList setDelegate:self];
	}

	return self;
}

- (IBAction)saveProject:(id)sender
{
}

- (void)getMoreBundles:(id)sender
{
	[self setSelectedLanguage:[[(ViDocument *)[self document] language] displayName]];
	[[ViPreferencesController sharedPreferences] performSelector:@selector(showItem:) withObject:@"BundlesItem" afterDelay:0.01];
}

- (void)newBundleLoaded:(NSNotification *)notification
{
	[languageButton removeAllItems];
	NSMenu *menu = [languageButton menu];
	NSMenuItem *item = [menu addItemWithTitle:@"Unknown" action:@selector(setLanguageAction:) keyEquivalent:@""];
	[item setTag:1001];
	[item setEnabled:NO];
	[[languageButton menu] addItem:[NSMenuItem separatorItem]];

	NSArray *languages = [[ViLanguageStore defaultStore] languages];
	NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"displayName" ascending:YES];
	NSArray *sortedLanguages = [languages sortedArrayUsingDescriptors:[NSArray arrayWithObject:descriptor]];

	for (ViLanguage *lang in sortedLanguages) {
		item = [menu addItemWithTitle:[lang displayName] action:@selector(setLanguageAction:) keyEquivalent:@""];
		[item setRepresentedObject:lang];
	}

	if ([[self document] respondsToSelector:@selector(language)])
		[self setSelectedLanguage:[[(ViDocument *)[self document] language] displayName]];

	if ([languages count] > 0)
		[[languageButton menu] addItem:[NSMenuItem separatorItem]];
	[menu addItemWithTitle:@"Get more bundles..." action:@selector(getMoreBundles:) keyEquivalent:@""];
}

- (void)windowDidResize:(NSNotification *)notification
{
	if (nagTitle) {
		NSView *view = [[[self window] contentView] superview];
	
		NSRect rect = [nagTitle frame];
		rect.origin.x = NSMaxX([view frame]) - rect.size.width - 35;
		rect.origin.y = NSMaxY([view frame]) - rect.size.height - (18 - rect.size.height);
		[nagTitle setFrame:rect];
	}

	[[self window] saveFrameUsingName:@"MainDocumentWindow"];
}

- (void)windowDidLoad
{
	[[[self window] toolbar] setShowsBaselineSeparator:NO];

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

	[self newBundleLoaded:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newBundleLoaded:) name:ViLanguageStoreBundleLoadedNotification object:nil];

	[splitView addSubview:explorerView positioned:NSWindowBelow relativeTo:mainView];
	[splitView addSubview:symbolsView];
	[splitView setAutosaveName:@"ProjectSymbolSplitView"];

	isLoaded = YES;
	if (initialDocument) {
		[self addNewTab:initialDocument];
                initialDocument = nil;
	}

	[[self window] makeKeyAndOrderFront:self];
	[symbolsView setSourceHighlight:YES];
	[explorerView setSourceHighlight:YES];
	[symbolsView setNeedsDisplay:YES];
	[explorerView setNeedsDisplay:YES];

	[symbolsOutline setTarget:self];
	[symbolsOutline setDoubleAction:@selector(goToSymbol:)];
	[symbolsOutline setAction:@selector(goToSymbol:)];

	[[symbolsOutline outlineTableColumn] setDataCell:[[MHTextIconCell alloc] init]];
	NSCell *cell = [(NSTableColumn *)[[symbolsOutline tableColumns] objectAtIndex:0] dataCell];
	[cell setLineBreakMode:NSLineBreakByTruncatingTail];
	[cell setWraps:NO];

	separatorCell = [[ViSeparatorCell alloc] init];

	if ([self project] != nil)
		[projectDelegate performSelector:@selector(addURL:) withObject:[[self project] initialURL] afterDelay:0.0];
	else
		[projectDelegate performSelector:@selector(addURL:) withObject:[environment baseURL] afterDelay:0.0];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(firstResponderChanged:) name:ViFirstResponderChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(caretChanged:) name:ViCaretChangedNotification object:nil];

	[self updateJumplistNavigator];
}

- (void)setSelectedLanguage:(NSString *)aLanguage
{
	if (aLanguage == nil)
		[languageButton selectItemWithTag:1001];
	else
		[languageButton selectItemWithTitle:aLanguage];
	[languageButton setToolTip:aLanguage];
}

- (IBAction)addNewDocumentTab:(id)sender
{
	[[NSDocumentController sharedDocumentController] newDocument:self];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"symbols"]) {
		[self filterSymbols:symbolFilterField];
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"autocollapse"] == YES) {
			[symbolsOutline collapseItem:nil collapseChildren:YES];
			[symbolsOutline expandItem:[self currentDocument]];
		}
		[self updateSelectedSymbolForLocation:[[[self currentView] textView] caret]];
	}
}

- (void)addDocument:(ViDocument *)document
{
	if ([documents containsObject:document]) {
		INFO(@"already got document %@", document);
		return;
	}

	NSArray *items = [[openFilesButton menu] itemArray];
	NSInteger ndx;
	for (ndx = 0; ndx < [items count]; ndx++)
		if ([[document displayName] compare:[[items objectAtIndex:ndx] title] options:NSCaseInsensitiveSearch] == NSOrderedAscending)
			break;
	NSMenuItem *item = [[openFilesButton menu] insertItemWithTitle:[document displayName]
								action:@selector(switchToDocumentAction:)
							 keyEquivalent:@""
							       atIndex:ndx];
	[item setRepresentedObject:document];

	// update symbol table
	[documents addObject:document];
	[self filterSymbols:symbolFilterField];
	[document addObserver:self forKeyPath:@"symbols" options:0 context:NULL];
        NSInteger row = [symbolsOutline rowForItem:document];
        [symbolsOutline scrollRowToVisible:row];
        [symbolsOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

	[document setJumpList:jumpList];
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

//	[[[self currentView] textView] pushCurrentLocationOnJumpList];

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

	// create a new document tab
	ViDocumentTabController *tabController = [[ViDocumentTabController alloc] initWithDocumentView:[document makeView]];

	NSTabViewItem *tabItem = [[NSTabViewItem alloc] initWithIdentifier:tabController];
	[tabItem setLabel:[document displayName]];
	[tabItem setView:[tabController view]];
	[tabView addTabViewItem:tabItem];
	[tabView selectTabViewItem:tabItem];

	[self addDocument:document];

	if (closeThisDocument) {
		[closeThisDocument close];
		[tabBar enableAnimations];
	}
}

- (void)documentChangedAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	ViDocument *document = contextInfo;

	if (returnCode == NSAlertSecondButtonReturn) {
		NSError *error = nil;
		[document revertToContentsOfURL:[document fileURL] ofType:[document fileType] error:&error];
		if (error) {
			[[alert window] orderOut:self];
			NSAlert *revertAlert = [NSAlert alertWithError:error];
			[revertAlert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
			[document updateChangeCount:NSChangeReadOtherContents];
		}
	}
}

- (void)checkDocumentChanged:(ViDocument *)document
{
	if ([[document fileURL] isFileURL]) {
		NSError *error = nil;
		NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[[document fileURL] path] error:&error];
		if (error) {
			NSAlert *alert = [NSAlert alertWithError:error];
			[alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
			[document updateChangeCount:NSChangeReadOtherContents];
			return;
		}

		NSDate *modificationDate = [attributes fileModificationDate];
		if ([[document fileModificationDate] compare:modificationDate] == NSOrderedAscending) {
			if ([document isDocumentEdited]) {
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
			} else {
				[document revertToContentsOfURL:[document fileURL] ofType:[document fileType] error:&error];
				if (error) {
					NSAlert *alert = [NSAlert alertWithError:error];
					[alert beginSheetModalForWindow:[self window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
					[document updateChangeCount:NSChangeReadOtherContents];
				}
			}
		}
	}
}

- (void)focusEditorDelayed:(id)sender
{
	if ([self currentView])
		[[self window] makeFirstResponder:[[self currentView] textView]];
}

- (void)focusEditor
{
	[self performSelector:@selector(focusEditorDelayed:) withObject:nil afterDelay:0.0];
}

- (ViTagStack *)sharedTagStack
{
	if (tagStack == nil)
		tagStack = [[ViTagStack alloc] init];
	return tagStack;
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
	NSString *projName = [[self project] displayName];
	if ([self currentDocument] == nil)
		return projName;
	return displayName;
}

- (void)windowDidBecomeMain:(NSNotification *)aNotification
{
	currentWindowController = self;
	[self checkDocumentChanged:[self currentDocument]];
}

- (ViDocument *)currentDocument
{
	return [[self currentView] document];
}

- (void)caretChanged:(NSNotification *)notification
{
	ViTextView *textView = [notification object];
	if (textView == [[self currentView] textView])
		[self updateSelectedSymbolForLocation:[textView caret]];
}

#pragma mark -
#pragma mark Document closing

- (void)documentController:(NSDocumentController *)docController didCloseAll:(BOOL)didCloseAll contextInfo:(void *)contextInfo
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
	[windowControllers removeObject:self];
	[tabBar setDelegate:nil];
}

- (ViDocumentView *)currentView
{
	return currentView;
}

- (void)closeTabController:(ViDocumentTabController *)tabController
{
	NSInteger ndx = [tabView indexOfTabViewItemWithIdentifier:tabController];
	if (ndx != NSNotFound) {
		NSTabViewItem *item = [tabView tabViewItemAtIndex:ndx];
		[tabView removeTabViewItem:item];
		[self tabView:tabView didCloseTabViewItem:item];

		while ([[tabController views] count] > 0) {
			ViDocumentView *docView = [[tabController views] objectAtIndex:0];
			ViDocument *doc = [docView document];
			if ([[doc views] count] == 1)
				[doc close];
			else
				[docView close];
		}
	}
}

- (void)document:(NSDocument *)doc shouldClose:(BOOL)shouldClose contextInfo:(void *)contextInfo
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
	ViDocumentView *docView = [self currentView];
	ViDocument *doc = [docView document];

	if ([[doc views] count] == 1)
		// closing the last view, close the document
		[doc canCloseDocumentWithDelegate:self shouldCloseSelector:@selector(document:shouldClose:contextInfo:) contextInfo:docView];
	else
		[self closeDocumentView:docView];
}

/*
 * Close the current view unless this is the last view in the window.
 * Called by C-w c.
 */
- (BOOL)closeCurrentViewUnlessLast
{
	ViDocumentView *docView = [self currentView];
	if ([tabView numberOfTabViewItems] > 1 || [[[docView tabController] views] count] > 1) {
		[self closeDocumentView:docView];
		return YES;
	}
	return NO;
}

- (void)closeDocumentView:(ViDocumentView *)docView
{
	[docView close];

	ViDocumentTabController *tabController = [docView tabController];
	if ([[tabController views] count] == 0)
		[self closeTabController:tabController];
	else if (tabController == [self selectedTabController])
		// Select another document view.
		[self selectDocumentView:[[tabController views] objectAtIndex:0]];
}

/*
 * Called by the document when it closes.
 * Removes all views of the document.
 */
- (void)closeDocument:(ViDocument *)document
{
	// Close all views of the document
	while ([[document views] count] > 0)
		[self closeDocumentView:[[document views] objectAtIndex:0]];

	NSInteger ndx = [[openFilesButton menu] indexOfItemWithRepresentedObject:document];
	if (ndx != -1)
		[[openFilesButton menu] removeItemAtIndex:ndx];

	[documents removeObject:document];
}

- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	// Give focus to the first (or last known?) view in the tab.
	ViDocumentTabController *tabController = [tabViewItem identifier];
	ViDocumentView *docView = [[tabController views] objectAtIndex:0];
	[self selectDocumentView:docView];
}

- (void)documentController:(NSDocumentController *)docController didCloseAll:(BOOL)didCloseAll tabController:(void *)tabController
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

	ViDocumentView *docView;
	for (docView in [tabController views]) {
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
#endif
			[self synchronizeWindowTitleWithDocumentName];
	}
}

#pragma mark -
#pragma mark Switching documents

- (void)firstResponderChanged:(NSNotification *)notification
{
	ViDocumentTabController *tabController = [self selectedTabController];
	for (ViDocumentView *docView in [tabController views])
		if ([docView textView] == [notification object]) {
			[self didSelectDocumentView:docView];
			return;
		}

	DEBUG(@"Can't find document view for text view %@ in this window.", [notification object]);
}

- (void)didSelectDocument:(ViDocument *)document
{
	if ([[self currentView] document] == document)
		return;

	[[self document] removeWindowController:self];
	[document addWindowController:self];
	[self setDocument:document];

	NSInteger ndx = [[openFilesButton menu] indexOfItemWithRepresentedObject:document];
	if (ndx != -1)
		[openFilesButton selectItemAtIndex:ndx];

	[self setSelectedLanguage:[[document language] displayName]];

	// update symbol list
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"autocollapse"] == YES)
		[symbolsOutline collapseItem:nil collapseChildren:YES];
        [symbolsOutline expandItem:document];

	[self checkDocumentChanged:document];

	[[self window] setTitle:[document displayName]];
	[[tabView selectedTabViewItem] setLabel:[document displayName]];
}

- (void)didSelectDocumentView:(ViDocumentView *)docView
{
	if (docView == [self currentView])
		return;

	[self didSelectDocument:[docView document]];
	[self updateSelectedSymbolForLocation:[[docView textView] caret]];

	lastDocumentView = currentView;
	currentView = docView;
}

/*
 * Selects the tab holding the given document view and focuses the view.
 */
- (ViDocumentView *)selectDocumentView:(ViDocumentView *)docView
{
	ViDocumentTabController *tabController = [docView tabController];

	NSTabViewItem *item = [tabView tabViewItemAtIndex:[tabView indexOfTabViewItemWithIdentifier:tabController]];
	[tabView selectTabViewItem:item];

	// Focus the text view
	[[self window] makeFirstResponder:[docView textView]];

	return docView;
}

/*
 * Selects the most appropriate view for the given document.
 * Will change current tab if no view of the document is visible in the current tab.
 *
 * What if the document is not visible in _any_ view? Create a new tab? Change the current view to show the given document?
 */
- (ViDocumentView *)selectDocument:(ViDocument *)document
{
	if (!isLoaded || document == nil)
		return nil;

	if ([[self currentView] document] == document)
		return [self selectDocumentView:[self currentView]];

	ViDocumentView *docView = nil;
	ViDocumentTabController *tabController = [self selectedTabController];

	// check if current tab has a view of the document
	for (docView in [tabController views])
		if ([[docView document] isEqual:document])
			return [self selectDocumentView:docView];
			

	// select any existing view of the document
	if ([[document views] count] > 0)
		return [self selectDocumentView:[[document views] objectAtIndex:0]];

	// No view exists of the document. Ugh. Create a new tab? Or just keep it hidden?
	INFO(@"No view exists of the document %@. DON'T KNOW WHAT TO DO!", document);

	return nil;
}

- (IBAction)selectNextTab:(id)sender
{
	NSArray *tabs = [tabBar representedTabViewItems];
	int num = [tabs count];
	if (num <= 1)
		return;

	int i;
	for (i = 0; i < num; i++)
	{
		if ([tabs objectAtIndex:i] == [tabView selectedTabViewItem])
		{
			if (++i >= num)
				i = 0;
//			[[[self currentView] textView] pushCurrentLocationOnJumpList];
			[tabView selectTabViewItem:[tabs objectAtIndex:i]];
			break;
		}
	}
}

- (IBAction)selectPreviousTab:(id)sender
{
	NSArray *tabs = [tabBar representedTabViewItems];
	int num = [tabs count];
	if (num <= 1)
		return;

	int i;
	for (i = 0; i < num; i++)
	{
		if ([tabs objectAtIndex:i] == [tabView selectedTabViewItem])
		{
			if (--i < 0)
				i = num - 1;
//			[[[self currentView] textView] pushCurrentLocationOnJumpList];
			[tabView selectTabViewItem:[tabs objectAtIndex:i]];
			break;
		}
	}
}

- (void)selectTabAtIndex:(NSInteger)anIndex
{
	NSArray *tabs = [tabBar representedTabViewItems];
//	[[[self currentView] textView] pushCurrentLocationOnJumpList];
	if (anIndex < [tabs count])
		[tabView selectTabViewItem:[tabs objectAtIndex:anIndex]];
}

- (void)switchToDocument:(ViDocument *)doc
{
	ViDocumentTabController *tabController = [self selectedTabController];
	ViDocumentView *docView = [tabController replaceDocumentView:[self currentView] withDocument:doc];
	[self selectDocumentView:docView];
}

- (void)switchToLastDocument
{
	[[[self currentView] textView] pushCurrentLocationOnJumpList];
	[self switchToDocument:[lastDocumentView document]];
}

- (void)selectLastDocument
{
	[[[self currentView] textView] pushCurrentLocationOnJumpList];
	[self selectDocumentView:lastDocumentView];
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
	if (doc) {
//		[[[self currentView] textView] pushCurrentLocationOnJumpList];
		[self switchToDocument:doc];
	}
}

- (ViDocument *)documentForURL:(NSURL *)url
{
	ViDocument *doc;
	for (doc in documents)
		if ([url isEqual:[doc fileURL]])
			return doc;
	return nil;
}

- (void)gotoURL:(NSURL *)url line:(NSUInteger)line column:(NSUInteger)column
{
	ViDocument *document = [self documentForURL:url];
	if (document == nil) {
		NSError *error = nil;
		document = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url display:YES error:&error];
		if (error) {
			[NSApp presentError:error];	
			return;
		}
	}

	ViDocumentView *docView = [self selectDocument:document];
	if (line > 0)
		[[docView textView] gotoLine:line column:column];
}

- (void)goToURL:(NSURL *)url
{
	[self gotoURL:url line:0 column:0];
}

#pragma mark -
#pragma mark View Splitting

- (IBAction)splitViewHorizontally:(id)sender
{
	ViDocumentView *docView = [self currentView];
	if (docView == nil) {
		NSLog(@"no current view?");
		return;
	}

	ViDocumentTabController *tabController = [docView tabController];
	[tabController splitView:docView vertically:NO];
	[self selectDocumentView:docView];
}

- (IBAction)splitViewVertically:(id)sender
{
	ViDocumentView *docView = [self currentView];
	if (docView == nil) {
		NSLog(@"no current view?");
		return;
	}

	ViDocumentTabController *tabController = [docView tabController];
	[tabController splitView:docView vertically:YES];
	[self selectDocumentView:docView];
}

- (ViDocumentView *)documentViewForView:(NSView *)aView
{
	for (ViDocument *doc in documents)
		for (ViDocumentView *docView in [doc views])
			if ([docView view] == aView || [docView textView] == aView)
				return docView;

	INFO(@"***** View %@ not in a document view", aView);
	return nil;
}

#pragma mark -
#pragma mark Split view delegate methods

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
	if (sender == splitView)
		return YES;
	return NO;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset
{
	if (sender == splitView) {
		NSView *view = [[sender subviews] objectAtIndex:offset];
		if (view == explorerView)
			return 100;
		if (view == symbolsView) {
			NSRect frame = [sender frame];
			return frame.size.width - 300;
		}
	}

	return proposedMin;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
{
	if (sender == splitView) {
		NSView *view = [[sender subviews] objectAtIndex:offset];
		if (view == explorerView)
			return 300;
		return proposedMax - 100;
	} else
		return proposedMax;
}

- (BOOL)splitView:(NSSplitView *)sender shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex
{
	if (sender == splitView)
	{
		// collapse both side views, but not the edit view
		if (subview == explorerView || subview == symbolsView)
			return NO;
		return YES;
	}
	else
		return NO;
}

- (void)splitView:(id)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	if (sender != splitView)
		return;

	int nsubviews = [[sender subviews] count];
	if (nsubviews < 2) {
		// the side views have not been added yet
		[sender adjustSubviews];
		return;
	}

	NSRect newFrame = [sender frame];
	float dividerThickness = [sender dividerThickness];

	NSInteger explorerWidth = 0;
	if ([[sender subviews] objectAtIndex:0] == explorerView) {
		if ([sender isSubviewCollapsed:explorerView])
			explorerWidth = 0;
		else
			explorerWidth = [explorerView frame].size.width;
	}

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

- (NSRect)splitView:(NSSplitView *)sender additionalEffectiveRectOfDividerAtIndex:(NSInteger)dividerIndex
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
		resizeRect.origin = [sender convertPoint:resizeRect.origin fromView:symbolsResizeView];
	} else
		return NSZeroRect;

	resizeRect.origin.y = NSHeight(frame) - NSHeight(resizeRect);
	return resizeRect;
}

#pragma mark -
#pragma mark Symbol List

- (IBAction)toggleSymbolList:(id)sender
{
	NSInteger ndx = ([[splitView subviews] objectAtIndex:0] == explorerView) ? 1 : 0;

	NSRect frame = [splitView frame];
	if ([splitView isSubviewCollapsed:symbolsView])
		[splitView setPosition:NSWidth(frame) - 200 ofDividerAtIndex:ndx];
	else
		[splitView setPosition:NSWidth(frame) ofDividerAtIndex:ndx];
}

- (void)goToSymbol:(ViSymbol *)aSymbol inDocument:(ViDocument *)document
{
	ViDocumentView *docView = [self selectDocument:document];

	NSRange range = [aSymbol range];
	ViTextView *textView = [docView textView];
	[textView setCaret:range.location];
	[textView scrollRangeToVisible:range];
	[textView showFindIndicatorForRange:range];
}

- (void)goToSymbol:(id)sender
{
	id item = [symbolsOutline itemAtRow:[symbolsOutline selectedRow]];

	// remember what symbol we selected from the filtered set
	NSString *filter = [symbolFilterField stringValue];
	if ([filter length] > 0)
	{
		[symbolFilterCache setObject:[item symbol] forKey:filter];
		[symbolFilterField setStringValue:@""];
	}

//	[[[self currentView] textView] pushCurrentLocationOnJumpList];

	if ([item isKindOfClass:[ViDocument class]])
		[self selectDocument:item];
	else
		[self goToSymbol:item inDocument:[symbolsOutline parentForItem:item]];

	if (closeSymbolListAfterUse)
	{
		[self toggleSymbolList:self];
		closeSymbolListAfterUse = NO;
	}
}

- (IBAction)searchSymbol:(id)sender
{
	if ([splitView isSubviewCollapsed:symbolsView])
	{
		closeSymbolListAfterUse = YES;
		[self toggleSymbolList:nil];
	}
	[[self window] makeFirstResponder:symbolFilterField];
}

- (void)selectFirstMatchingSymbolForFilter:(NSString *)filter
{
	NSUInteger row;

	NSString *symbol = [symbolFilterCache objectForKey:filter];
	if (symbol)
	{
		// check if the cached symbol is available, then select it
		for (row = 0; row < [symbolsOutline numberOfRows]; row++)
		{
			id item = [symbolsOutline itemAtRow:row];
			if ([item isKindOfClass:[ViSymbol class]] && [[item symbol] isEqualToString:symbol])
			{
				[symbolsOutline scrollRowToVisible:row];
				[symbolsOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
				return;
			}
		}
	}

	// skip past all document entries, selecting the first symbol
	for (row = 0; row < [symbolsOutline numberOfRows]; row++)
	{
		id item = [symbolsOutline itemAtRow:row];
		if ([item isKindOfClass:[ViSymbol class]])
		{
			[symbolsOutline scrollRowToVisible:row];
			[symbolsOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
			break;
		}
	}
}

- (IBAction)filterSymbols:(id)sender
{
	NSString *filter = [sender stringValue];

	NSMutableString *pattern = [NSMutableString string];
	int i;
	for (i = 0; i < [filter length]; i++)
	{
		[pattern appendFormat:@".*%C", [filter characterAtIndex:i]];
	}
	[pattern appendString:@".*"];

	ViRegexp *rx = [ViRegexp regularExpressionWithString:pattern options:ONIG_OPTION_IGNORECASE];

	filteredDocuments = [[NSMutableArray alloc] initWithArray:documents];

	// make sure the current document is displayed first in the symbol list
	ViDocument *currentDocument = [self currentDocument];
	if (currentDocument)
	{
		[filteredDocuments removeObject:currentDocument];
		[filteredDocuments insertObject:currentDocument atIndex:0];
	}

	ViDocument *doc;
	NSMutableArray *emptyDocuments = [[NSMutableArray alloc] init];
	for (doc in filteredDocuments)
	{
		if ([doc filterSymbols:rx] == 0)
			[emptyDocuments addObject:doc];
	}
	[filteredDocuments removeObjectsInArray:emptyDocuments];
	[symbolsOutline reloadData];
	[symbolsOutline expandItem:nil expandChildren:YES];
	[self selectFirstMatchingSymbolForFilter:filter];
}

- (void)updateSelectedSymbolForLocation:(NSUInteger)aLocation
{
	NSArray *symbols = [[self currentDocument] symbols];
	ViSymbol *symbol;
	id item = [self currentDocument];
	for (symbol in symbols)
	{
		NSRange r = [symbol range];
		if (r.location > aLocation)
			break;
		item = symbol;
	}

	if (item)
	{
		NSUInteger row = [symbolsOutline rowForItem:item];
		[symbolsOutline scrollRowToVisible:row];
		[symbolsOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	}
}

#pragma mark -

- (IBAction)searchFiles:(id)sender
{
	[projectDelegate searchFiles:sender];
}

- (IBAction)toggleExplorer:(id)sender
{
	if ([[splitView subviews] objectAtIndex:0] == explorerView)
		[projectDelegate toggleExplorer:sender];
	else
		NSBeep();
}

#pragma mark -
#pragma mark Ex filename completion

- (BOOL)control:(NSControl *)sender textView:(NSTextView *)textView doCommandBySelector:(SEL)aSelector
{
	if (sender == symbolFilterField)
	{
		if (aSelector == @selector(insertNewline:)) // enter
		{
			[self goToSymbol:self];
			return YES;
		}
		else if (aSelector == @selector(moveUp:)) // up arrow
		{
			NSInteger row = [symbolsOutline selectedRow];
			if (row > 0)
			{
				[symbolsOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:row - 1] byExtendingSelection:NO];
			}
			return YES;
		}
		else if (aSelector == @selector(moveDown:)) // down arrow
		{
			NSInteger row = [symbolsOutline selectedRow];
			if (row + 1 < [symbolsOutline numberOfRows])
			{
				[symbolsOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:row + 1] byExtendingSelection:NO];
			}
			return YES;
		}
		else if (aSelector == @selector(cancelOperation:)) // escape
		{
			if (closeSymbolListAfterUse)
			{
				[self toggleSymbolList:self];
				closeSymbolListAfterUse = NO;
			}
			[symbolFilterField setStringValue:@""];
			[self focusEditor];
			return YES;
		}
	}
	return NO;
}

#pragma mark -
#pragma mark Symbol Outline View Data Source

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)anIndex ofItem:(id)item
{
	if (item == nil)
		return [filteredDocuments objectAtIndex:anIndex];
	return [[(ViDocument *)item filteredSymbols] objectAtIndex:anIndex];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	if ([item isKindOfClass:[ViDocument class]])
		return [[(ViDocument *)item filteredSymbols] count] > 0 ? YES : NO;
	return NO;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if (item == nil)
		return [filteredDocuments count];

	if ([item isKindOfClass:[ViDocument class]])
		return [[(ViDocument *)item filteredSymbols] count];

	return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	return [item displayName];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
	if ([item isKindOfClass:[ViDocument class]])
		return YES;
	return NO;
}

- (BOOL)isSeparatorItem:(id)item
{
	if ([item isKindOfClass:[ViSymbol class]] && [[(ViSymbol *)item symbol] isEqualToString:@"-"])
		return YES;
	return NO;
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
	if ([self isSeparatorItem:item])
		return 9;
	if ([self outlineView:outlineView isGroupItem:item])
		return 20;
	return 15;
}

- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	NSCell *cell;
	if ([self isSeparatorItem:item])
		cell = separatorCell;
	else {
		cell  = [tableColumn dataCellForRow:[symbolsOutline rowForItem:item]];

		if ([item respondsToSelector:@selector(image)])
			[cell setImage:[item image]];
		else
			[cell setImage:nil];
	}

	if (![item isKindOfClass:[ViDocument class]])
		[cell setFont:[NSFont systemFontOfSize:11.0]];
	else
		[cell setFont:[NSFont systemFontOfSize:13.0]];
		
	return cell;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
	return ![self isSeparatorItem:item];
}

#pragma mark -
#pragma mark Jumplist navigation

- (IBAction)navigateJumplist:(id)sender
{
	NSURL *url;
	NSUInteger line, column;
	ViTextView *tv = [[self currentView] textView];

	if (tv == nil)
		return;

	if ([sender selectedSegment] == 0) {
		url = [[self document] fileURL];
		line = [[tv textStorage] lineNumberAtLocation:[tv caret]];
		column = [[tv textStorage] columnAtLocation:[tv caret]];
		[jumpList backwardToURL:&url line:&line column:&column];
	} else {
		[jumpList forwardToURL:NULL line:NULL column:NULL];
	}
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
	[self gotoURL:[jump url] line:[jump line] column:[jump column]];
	[self updateJumplistNavigator];
}

@end

