#import "ViWindowController.h"
#import <PSMTabBarControl/PSMTabBarControl.h>
#import "ViDocument.h"
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
#include "license.h"

static NSMutableArray		*windowControllers = nil;
static NSWindowController	*currentWindowController = nil;

@interface ViWindowController ()
- (ViDocumentView *)documentViewForView:(NSView *)aView;
- (void)collapseDocumentView:(ViDocumentView *)docView;
- (ViDocument *)documentForURL:(NSURL *)url;
@end


#pragma mark -
@implementation ViWindowController

@synthesize documents;
@synthesize selectedDocument;
@synthesize statusbar;
@synthesize messageField;
@synthesize currentDirectory;
@synthesize project;

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
                [self changeCurrentDirectory:[[NSFileManager defaultManager] currentDirectoryPath]];
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
	NSMenuItem *item = [menu addItemWithTitle:@"Unknown" action:@selector(setLanguage:) keyEquivalent:@""];
	[item setTag:1001];
	[item setEnabled:NO];
	[[languageButton menu] addItem:[NSMenuItem separatorItem]];

	NSArray *languages = [[ViLanguageStore defaultStore] languages];
	NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"displayName" ascending:YES];
	NSArray *sortedLanguages = [languages sortedArrayUsingDescriptors:[NSArray arrayWithObject:descriptor]];

	for (ViLanguage *lang in sortedLanguages) {
		item = [menu addItemWithTitle:[lang displayName] action:@selector(setLanguage:) keyEquivalent:@""];
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

- (void)licenseChanged:(NSNotification *)notification
{
	NSString *licenseKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"licenseKey"];
	NSString *licenseOwner = [[NSUserDefaults standardUserDefaults] stringForKey:@"licenseOwner"];
	NSString *licenseEmail = [[NSUserDefaults standardUserDefaults] stringForKey:@"licenseEmail"];
	if (check_license_3([licenseOwner UTF8String], [licenseEmail UTF8String], [licenseKey UTF8String], NULL, NULL, NULL) == 0) {
		if (nagTitle)
			[nagTitle removeFromSuperview];
		nagTitle = nil;
	} else if (nagTitle == nil) {
		NSView *view = [[[self window] contentView] superview];
		time_t ltime = get_first_launch_date([[ViAppController supportDirectory] fileSystemRepresentation]);
		time_t now = time(NULL);
		unsigned int days = (now - ltime) / 86400 + 1;
		NSString *s = [NSString stringWithFormat:@"Evaluated for %u day%s.", days, days == 1 ? "" : "s"];
		NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
		if (days > 30) {
			[attrs setObject:[NSColor redColor] forKey:NSForegroundColorAttributeName];
			[attrs setObject:[NSFont boldSystemFontOfSize:12.0] forKey:NSFontAttributeName];
		} else
			[attrs setObject:[NSFont titleBarFontOfSize:10.0] forKey:NSFontAttributeName];
		NSRect rect;
		rect.size = [s sizeWithAttributes:attrs];
		rect.size.width += 10;
		rect.origin.x = NSMaxX([view frame]) - rect.size.width - 35;
		rect.origin.y = NSMaxY([view frame]) - rect.size.height - (18 - rect.size.height);
		nagTitle = [[NSTextField alloc] initWithFrame:rect];
		[nagTitle setDrawsBackground:NO];
		[nagTitle setEditable:NO];
		[nagTitle setBezeled:NO];
		[nagTitle setTextColor:[NSColor blackColor]];
		[nagTitle setStringValue:[[NSAttributedString alloc] initWithString:s attributes:attrs]];
		[view addSubview:nagTitle];
	}
}

- (void)windowDidLoad
{
	[[[self window] toolbar] setShowsBaselineSeparator:NO];

	[self licenseChanged:nil];

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

	if ([self project] != nil)
		[splitView addSubview:explorerView positioned:NSWindowBelow relativeTo:documentView];
	[splitView addSubview:symbolsView];
	[splitView setAutosaveName:@"ProjectSymbolSplitView"];

	isLoaded = YES;
	if (initialDocument) {
		[self addNewTab:initialDocument];
                lastDocument = initialDocument;
                lastDocumentView = [[lastDocument views] objectAtIndex:0];
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

	[statusbar setFont:[NSFont userFixedPitchFontOfSize:12.0]];
	[statusbar setDelegate:self];

	separatorCell = [[ViSeparatorCell alloc] init];

	[commandSplit setPosition:NSHeight([commandSplit frame]) ofDividerAtIndex:0];
	[commandOutput setFont:[NSFont userFixedPitchFontOfSize:10.0]];

	if ([self project] != nil)
		[projectDelegate performSelector:@selector(addURL:) withObject:[[self project] initialURL] afterDelay:0.0];

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(licenseChanged:)
						     name:ViLicenseChangedNotification
						   object:nil];
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
		[self updateSelectedSymbolForLocation:[(ViTextView *)[mostRecentView textView] caret]];
	}
}

/* Called by a new ViDocument in its makeWindowControllers method.
 */
- (void)addNewTab:(ViDocument *)document
{
	if (!isLoaded)
	{
		/* Defer until NIB is loaded. */
		initialDocument = document;
		return;
	}

	if (mostRecentView)
		[(ViTextView *)[mostRecentView textView] pushCurrentLocationOnJumpList];

	/*
	 * If current document is untitled and unchanged and the rightmost tab, replace it.
	 */
	ViDocument *closeThisDocument = nil;
	if ([self currentDocument] != nil &&
	    [[self currentDocument] fileURL] == nil &&
	    [document fileURL] != nil && ![[self currentDocument] isDocumentEdited] &&
	    [self currentDocument] == [[tabBar representedDocuments] lastObject]) {
		[tabBar disableAnimations];
		closeThisDocument = [self currentDocument];
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
	[tabBar addDocument:document];
	[self selectDocument:document];

	// update symbol table
	[documents addObject:document];
	[self filterSymbols:symbolFilterField];
	[document addObserver:self forKeyPath:@"symbols" options:0 context:NULL];
        NSInteger row = [symbolsOutline rowForItem:document];
        [symbolsOutline scrollRowToVisible:row];
        [symbolsOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

	[[ViJumpList defaultJumpList] pushURL:[document fileURL] line:1 column:1];

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

- (void)setMostRecentDocument:(ViDocument *)document view:(ViDocumentView *)docView
{
	if (mostRecentView == docView)
		return;

	lastDocument = mostRecentDocument;
	lastDocumentView = mostRecentView;

	mostRecentDocument = document;
	mostRecentView = docView;

	[[self document] removeWindowController:self];
	[document addWindowController:self];
	[self setDocument:document];

	NSInteger ndx = [[openFilesButton menu] indexOfItemWithRepresentedObject:document];
	if (ndx != -1)
		[openFilesButton selectItemAtIndex:ndx];

	[self setSelectedLanguage:[[document language] displayName]];
	[self setSelectedDocument:document];
	[tabBar didSelectDocument:document];

	[[self window] makeFirstResponder:[docView textView]];
 
	// update symbol list
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"autocollapse"] == YES)
		[symbolsOutline collapseItem:nil collapseChildren:YES];
        [symbolsOutline expandItem:document];
	[self updateSelectedSymbolForLocation:[(ViTextView *)[docView textView] caret]];

	[self checkDocumentChanged:document];
}

- (void)selectDocument:(ViDocument *)aDocument
{
	if (!isLoaded || aDocument == nil)
		return;

	if (mostRecentDocument == aDocument)
		return;

	// create a new document view
	ViDocumentView *docView = [aDocument makeView];

	// add the new view
	if (mostRecentView == nil) {
		NSRect frame = [documentView frame];
		frame.origin = NSMakePoint(0, 0);
		NSSplitView *split = [[NSSplitView alloc] initWithFrame:frame];
		[split setVertical:NO];
		[split setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		[split addSubview:[docView view]];
		[split adjustSubviews];
		[documentView addSubview:split];
	} else {
		[mostRecentDocument removeView:mostRecentView];
		NSView *superView = [[mostRecentView view] superview];
		[superView replaceSubview:[mostRecentView view] with:[docView view]];
		mostRecentView = nil;
	}

	[self setMostRecentDocument:aDocument view:docView];
}

- (void)focusEditor
{
	[[self window] makeFirstResponder:[mostRecentView textView]];
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

	[[NSDocumentController sharedDocumentController] closeAllDocumentsInWindow:window
								      withDelegate:self
							       didCloseAllSelector:@selector(documentController:didCloseAll:contextInfo:)];
	return NO;
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	if (currentWindowController == self)
		currentWindowController = nil;
	[windowControllers removeObject:self];
	[tabBar setDelegate:nil];
}

- (void)synchronizeWindowTitleWithDocumentName
{
	[super synchronizeWindowTitleWithDocumentName];

	/* Sync title with tab bar here. */
}

- (void)closeDocumentViews:(ViDocument *)document
{
	while ([document visibleViews] > 0)
		[self collapseDocumentView:[[document views] objectAtIndex:0]];

	NSInteger ndx = [[openFilesButton menu] indexOfItemWithRepresentedObject:document];
	if (ndx != -1)
		[[openFilesButton menu] removeItemAtIndex:ndx];

	[tabBar removeDocument:document];
	if (lastDocument == document) {
		lastDocument = nil;
		lastDocumentView = nil;
	}

	[documents removeObject:document];

	/* Reset the most recent document and view.
	 */
	mostRecentView = nil;
	mostRecentDocument = nil;

	if ([documents count] == 0) {
		if ([self project] == nil)
			[[self window] close];
		else
			[self synchronizeWindowTitleWithDocumentName];
	} else {
		BOOL foundVisibleView = NO;
		if (lastDocument && lastDocument != document) {
			[self switchToLastDocument];
			foundVisibleView = YES;
		}

		if (!foundVisibleView) {
			for (document in documents) {
				if ([document visibleViews] > 0) {
					[self setMostRecentDocument:document view:[[document views] objectAtIndex:0]];
					foundVisibleView = YES;
					break;
				}
			}
		}

		if (!foundVisibleView) {
			// no visible view found, make one
			[self selectDocument:[documents objectAtIndex:0]];
		}

		[self filterSymbols:symbolFilterField];
	}
}

- (void)document:(NSDocument *)doc shouldClose:(BOOL)shouldClose contextInfo:(void *)contextInfo
{
	if (shouldClose)
		[doc close];
}

/*
 * Called by the tabBar when clicking the X button in the tab.
 */
- (void)closeDocument:(ViDocument *)document
{
	if (document == nil && [[self documents] count] == 0) {
		mostRecentView = nil;
		mostRecentDocument = nil;
		[[self project] close];
		[[self window] close];
		return;
	}

	if ([document visibleViews] > 0)
		[self setMostRecentDocument:document view:[[document views] objectAtIndex:0]];
	else
		[self selectDocument:document];

	[document canCloseDocumentWithDelegate:self shouldCloseSelector:@selector(document:shouldClose:contextInfo:) contextInfo:NULL];
}

#pragma mark -
#pragma mark Switching documents

- (void)windowDidBecomeMain:(NSNotification *)aNotification
{
	currentWindowController = self;
	[self checkDocumentChanged:[self currentDocument]];
}

- (ViDocument *)currentDocument
{
	return mostRecentDocument;
}

- (IBAction)selectNextTab:(id)sender
{
	NSArray *tabs = [tabBar representedDocuments];
	int num = [tabs count];
	if (num <= 1)
		return;

	int i;
	for (i = 0; i < num; i++)
	{
		if ([tabs objectAtIndex:i] == [self selectedDocument])
		{
			if (++i >= num)
				i = 0;
			[self selectDocument:[tabs objectAtIndex:i]];
			break;
		}
	}
}

- (IBAction)selectPreviousTab:(id)sender
{
	NSArray *tabs = [tabBar representedDocuments];
	int num = [tabs count];
	if (num <= 1)
		return;

	int i;
	for (i = 0; i < num; i++)
	{
		if ([tabs objectAtIndex:i] == [self selectedDocument])
		{
			if (--i < 0)
				i = num - 1;
			[self selectDocument:[tabs objectAtIndex:i]];
			break;
		}
	}
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
	if (projName)
		return [NSString stringWithFormat:@"%@ - %@", displayName, projName];
	return displayName;
}

- (void)switchToDocument:(ViDocument *)doc view:(ViDocumentView *)view
{
	if ([doc visibleViews] > 0)
		[self setMostRecentDocument:doc view:view ?: [[doc views] objectAtIndex:0]];
	else
		[self selectDocument:doc];
}

- (void)switchToDocument:(ViDocument *)doc
{
	[self switchToDocument:doc view:nil];
}

- (void)switchToLastDocument
{
	[self switchToDocument:lastDocument view:lastDocumentView];
}

- (void)switchToDocumentAtIndex:(NSInteger)anIndex
{
	if (anIndex < [[tabBar representedDocuments] count])
		[self switchToDocument:[[tabBar representedDocuments] objectAtIndex:anIndex]];
}

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

- (void)gotoURL:(NSURL *)url line:(NSUInteger)line column:(NSUInteger)column
{
	ViDocument *document = [self documentForURL:url];
	if (document == nil) {
		NSError *error = nil;
		[[NSDocumentController sharedDocumentController]
		    openDocumentWithContentsOfURL:url display:YES error:&error];
		if (error)
			[NSApp presentError:error];	
	} else if ([self currentDocument] != document)
		[self switchToDocument:document];

	if (line > 0)
		[(ViTextView *)[mostRecentView textView] gotoLine:line column:column];
}

- (void)goToURL:(NSURL *)url
{
	[self gotoURL:url line:0 column:0];
}

#pragma mark -
#pragma mark View Splitting

- (IBAction)splitViewHorizontally:(id)sender
{
	NSView *view = [mostRecentView view];
	NSSplitView *split = (NSSplitView *)[view superview];
	if (![split isKindOfClass:[NSSplitView class]])
	{
		INFO(@"***** superview not an NSSplitView!? %@", split);
		return;
	}

	ViDocumentView *dv = [mostRecentDocument makeView];

	if (![split isVertical])
	{
		// Just add another view to this split
		[split addSubview:[dv view]];
		[split adjustSubviews];
	}
	else
	{
		// Need to create a new horizontal split view and replace
		// the current view with the split and two subviews
		NSRect frame = [view frame];
		frame.origin = NSMakePoint(0, 0);
		NSSplitView *newSplit = [[NSSplitView alloc] initWithFrame:frame];
		[newSplit setVertical:NO];
		[newSplit setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		[split replaceSubview:view with:newSplit];
		[newSplit addSubview:view];
		[newSplit addSubview:[dv view]];
		[newSplit adjustSubviews];
	}

	[self setMostRecentDocument:mostRecentDocument view:dv];
}

- (IBAction)splitViewVertically:(id)sender
{
	NSView *view = [mostRecentView view];
	NSSplitView *split = (NSSplitView *)[view superview];
	if (![split isKindOfClass:[NSSplitView class]])
	{
		INFO(@"***** superview not an NSSplitView!? %@", split);
		return;
	}

	ViDocumentView *dv = [mostRecentDocument makeView];
	int nsubviews = [[split subviews] count];
	if ([split isVertical])
	{
		// Just add another view to this split
		[split addSubview:[dv view]];
		[split adjustSubviews];
	}
	else
	{
		if (nsubviews == 1)
		{
			// There is only one view in this horizontal split.
			// Change it to a vertical split.
			[split setVertical:YES];
			[split addSubview:[dv view]];
			[split adjustSubviews];
		}
		else
		{
			// Need to create a new vertial split view and replace
			// the current view with the split and two subviews
			NSRect frame = [view frame];
			frame.origin = NSMakePoint(0, 0);
			NSSplitView *newSplit = [[NSSplitView alloc] initWithFrame:frame];
			[newSplit setVertical:YES];
			[newSplit setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
			[split replaceSubview:view with:newSplit];
			[newSplit addSubview:view];
			[newSplit addSubview:[dv view]];
			[newSplit adjustSubviews];
		}
	}

	[self setMostRecentDocument:mostRecentDocument view:dv];
}

- (ViDocumentView *)documentViewForView:(NSView *)aView
{
	ViDocument *doc;
	for (doc in documents) // XXX: should maybe ask the tab bar for the documents?
	{
		ViDocumentView *dv;
		for (dv in [doc views])
			if ([dv view] == aView)
				return dv;
	}
	INFO(@"***** View %@ not a document view!?", aView);
	return nil;
}

- (IBAction)collapseSplitView:(id)sender
{
	NSView *view = [mostRecentView view];
	NSSplitView *split = (NSSplitView *)[view superview];
	if (![split isKindOfClass:[NSSplitView class]])
	{
		INFO(@"***** superview not an NSSplitView!? %@", split);
		return;
	}

	if ([[split subviews] count] == 1)
	{
		// beep
		return;
	}

	// Find index of current subview.
	int cur;
	for (cur = 0; cur < [[split subviews] count]; cur++)
	{
		if ([[split subviews] objectAtIndex:cur] == view)
			break;
	}

	NSView *delView;
	if (cur == 0)
		delView = [[split subviews] objectAtIndex:1];
	else
		delView = [[split subviews] objectAtIndex:cur - 1];

        if ([delView isKindOfClass:[NSSplitView class]])
        {
                [[mostRecentView document] message:@"Can't collapse when other window is split"];
                return;
        }

	ViDocumentView *docView = [self documentViewForView:delView];
	[self collapseDocumentView:docView];
}

- (void)collapseDocumentView:(ViDocumentView *)docView
{
	[[docView document] removeView:docView];

	NSSplitView *split = (NSSplitView *)[[docView view] superview];

	[[docView view] removeFromSuperview];

	if (![split isKindOfClass:[NSSplitView class]])
	{
		INFO(@"***** superview not an NSSplitView!? %@", split);
		return;
	}

	if ([[split subviews] count] == 1)
	{
		NSSplitView *supersplit = (NSSplitView *)[split superview];
		if ([supersplit isKindOfClass:[NSSplitView class]])
		{
			NSView *view = [[split subviews] objectAtIndex:0];
			[view removeFromSuperview];
			[supersplit replaceSubview:split with:view];
			[supersplit adjustSubviews];
		}
	}
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

	[(ViTextView *)[mostRecentView textView] pushCurrentLocationOnJumpList];

	if ([item isKindOfClass:[ViDocument class]])
	{
		ViDocument *document = item;
		if ([self currentDocument] != document)
			[self switchToDocument:document];
		else 
			[self updateSelectedSymbolForLocation:[(ViTextView *)[mostRecentView textView] caret]];
	}
	else
	{
		ViDocument *document = [symbolsOutline parentForItem:item];
		if ([self currentDocument] != document)
			[self switchToDocument:document];
		[document goToSymbol:item];
	}

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

- (BOOL)changeCurrentDirectory:(NSString *)path
{
        NSString *p;
        if ([path isAbsolutePath])
                p = [path stringByStandardizingPath];
        else
                p = [[[self currentDirectory] stringByAppendingPathComponent:path] stringByStandardizingPath];

        BOOL isDirectory = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:p isDirectory:&isDirectory] && isDirectory)
        {
                currentDirectory = p;
                return YES;
        }
        else
        {
                INFO(@"failed to set current directory to '%@'", p);
                return NO;
        }
}

- (NSString *)filenameAtLocation:(NSUInteger)aLocation inFieldEditor:(NSText *)fieldEditor range:(NSRange *)outRange
{
	NSString *s = [fieldEditor string];
	NSRange r = [s rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]
				       options:NSBackwardsSearch
					 range:NSMakeRange(0, aLocation)];

	if (r.location++ == NSNotFound)
		r.location = 0;

	r.length = aLocation - r.location;
	*outRange = r;

	return [s substringWithRange:r];
}

- (unsigned)completePath:(NSString *)partialPath intoString:(NSString **)longestMatchPtr matchesIntoArray:(NSArray **)matchesPtr
{
	NSFileManager *fm = [NSFileManager defaultManager];

	NSString *path;
	NSString *suffix;
	if ([partialPath hasSuffix:@"/"])
	{
		path = partialPath;
		suffix = @"";
	}
	else
	{
		path = [partialPath stringByDeletingLastPathComponent];
		suffix = [partialPath lastPathComponent];
	}

	NSArray *directoryContents = [fm directoryContentsAtPath:[path stringByExpandingTildeInPath]];
	NSMutableArray *matches = [[NSMutableArray alloc] init];
	NSString *entry;
	for (entry in directoryContents)
	{
		if ([entry compare:suffix options:NSCaseInsensitiveSearch range:NSMakeRange(0, [suffix length])] == NSOrderedSame)
		{
			if ([entry hasPrefix:@"."] && ![suffix hasPrefix:@"."])
				continue;
			NSString *s = [path stringByAppendingPathComponent:entry];
			BOOL isDirectory = NO;
			if ([fm fileExistsAtPath:[s stringByExpandingTildeInPath] isDirectory:&isDirectory] && isDirectory)
				[matches addObject:[s stringByAppendingString:@"/"]];
			else
				[matches addObject:s];
		}
	}

	if (longestMatchPtr && [matches count] > 0)
	{
		NSString *longestMatch = nil;
		NSString *firstMatch = [matches objectAtIndex:0];
		NSString *m;
		for (m in matches)
		{
			NSString *commonPrefix = [firstMatch commonPrefixWithString:m options:NSCaseInsensitiveSearch];
			if (longestMatch == nil || [commonPrefix length] < [longestMatch length])
				longestMatch = commonPrefix;
		}
		*longestMatchPtr = longestMatch;
	}

	if (matchesPtr)
		*matchesPtr = matches;

	return [matches count];
}

- (void)displayCompletions:(NSArray *)completions forPath:(NSString *)path
{
	int skipIndex;
	if ([path hasSuffix:@"/"])
		skipIndex = [path length];
	else
		skipIndex = [[path stringByDeletingLastPathComponent] length] + 1;

	NSDictionary *attrs = [NSDictionary dictionaryWithObject:[NSFont userFixedPitchFontOfSize:11.0]
							  forKey:NSFontAttributeName];
	NSString *c;
	NSSize maxsize = NSMakeSize(0, 0);
	for (c in completions)
	{
		NSSize size = [[c substringFromIndex:skipIndex] sizeWithAttributes:attrs];
		if (size.width > maxsize.width)
			maxsize = size;
	}

	CGFloat colsize = maxsize.width + 50;

	NSRect bounds = [commandOutput bounds];
	int columns = NSWidth(bounds) / colsize;
	if (columns <= 0)
		columns = 1;

	// remove all previous tab stops
	NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	NSTextTab *tabStop;
	for (tabStop in [style tabStops])
	{
		[style removeTabStop:tabStop];
	}
	[style setDefaultTabInterval:colsize];

	[[[commandOutput textStorage] mutableString] setString:@""];
	int n = 0;
	for (c in completions)
	{
		[[[commandOutput textStorage] mutableString] appendFormat:@"%@%@",
			[c substringFromIndex:skipIndex], (++n % columns) == 0 ? @"\n" : @"\t"];
	}

	ViTheme *theme = [[ViThemeStore defaultStore] defaultTheme];
	[commandOutput setBackgroundColor:[theme backgroundColor]];
	[commandOutput setSelectedTextAttributes:[NSDictionary dictionaryWithObject:[theme selectionColor]
								             forKey:NSBackgroundColorAttributeName]];
	attrs = [NSDictionary dictionaryWithObjectsAndKeys:
			style, NSParagraphStyleAttributeName,
			[theme foregroundColor], NSForegroundColorAttributeName,
			[theme backgroundColor], NSBackgroundColorAttributeName,
			[NSFont userFixedPitchFontOfSize:11.0], NSFontAttributeName,
			nil];
	[[commandOutput textStorage] addAttributes:attrs range:NSMakeRange(0, [[commandOutput textStorage] length])];

        // display the completion by expanding the commandSplit view
	[commandSplit setPosition:NSHeight([commandSplit frame])*0.60 ofDividerAtIndex:0];
}

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
	else if (sender == statusbar)
	{
		NSText *fieldEditor = [[self window] fieldEditor:NO forObject:sender];
		if (aSelector == @selector(cancelOperation:) || // escape
		    aSelector == @selector(noop:) ||            // ctrl-c and ctrl-g ...
		    aSelector == @selector(insertNewline:) ||
		    (aSelector == @selector(deleteBackward:) && [fieldEditor selectedRange].location == 0))
		{
			[commandSplit setPosition:NSHeight([commandSplit frame]) ofDividerAtIndex:0];
			if (aSelector != @selector(insertNewline:))
				[statusbar setStringValue:@""];
			[[statusbar target] performSelector:[statusbar action] withObject:self];
			return YES;
		}
		else if (aSelector == @selector(moveUp:))
		{
			INFO(@"%s", "look back in history");
			return YES;
		}
		else if (aSelector == @selector(moveDown:))
		{
			INFO(@"%s", "look forward in history");
			return YES;
		}
		else if (aSelector == @selector(insertBacktab:))
		{
			return YES;
		}
		else if (aSelector == @selector(insertTab:) ||
		         aSelector == @selector(deleteForward:)) // ctrl-d
		{
			NSUInteger caret = [fieldEditor selectedRange].location;
			NSRange range;
			NSString *filename = [self filenameAtLocation:caret inFieldEditor:fieldEditor range:&range];

			if (![filename isAbsolutePath])
                        {
				filename = [[self currentDirectory] stringByAppendingPathComponent:filename];
                        }
                        filename = [[filename stringByStandardizingPath] stringByAbbreviatingWithTildeInPath];

                        if ([filename isEqualToString:@"~"])
                                filename = @"~/";

			NSArray *completions = nil;
			NSString *completion = nil;
			NSUInteger num = [self completePath:filename intoString:&completion matchesIntoArray:&completions];
	
			if (completion)
			{
				NSMutableString *s = [[NSMutableString alloc] initWithString:[fieldEditor string]];
				[s replaceCharactersInRange:range withString:completion];
				[fieldEditor setString:s];
			}

			if (num == 1 && [completion hasSuffix:@"/"])
			{
				/* If only one directory match, show completions inside that directory. */
				num = [self completePath:completion intoString:&completion matchesIntoArray:&completions];
			}

			if (num > 1)
			{
				[self displayCompletions:completions forPath:completion];
			}
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

@end

