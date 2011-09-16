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

static NSMutableArray		*windowControllers = nil;
static ViWindowController	*currentWindowController = nil;

@interface ViWindowController ()
- (void)updateJumplistNavigator;
- (void)didSelectDocument:(ViDocument *)document;
- (void)didSelectViewController:(id<ViViewController>)viewController;
- (void)closeDocumentView:(id<ViViewController>)viewController
	 canCloseDocument:(BOOL)canCloseDocument
	   canCloseWindow:(BOOL)canCloseWindow;
- (void)documentController:(NSDocumentController *)docController
	       didCloseAll:(BOOL)didCloseAll
	     tabController:(void *)tabController;
- (void)unlistDocument:(ViDocument *)document;
@end


#pragma mark -
@implementation ViWindowController

@synthesize documents;
@synthesize project;
@synthesize explorer;
@synthesize jumpList, jumping;
@synthesize tagStack, tagsDatabase;
@synthesize previousDocument;
@synthesize baseURL;
@synthesize symbolController;

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
		tagStack = [[ViTagStack alloc] init];
		[self setBaseURL:[NSURL fileURLWithPath:NSHomeDirectory()]];
	}

	return self;
}

- (ViTagsDatabase *)tagsDatabase
{
	if (![[tagsDatabase baseURL] isEqualToURL:baseURL])
		tagsDatabase = nil;

	if (tagsDatabase == nil)
		tagsDatabase = [[ViTagsDatabase alloc] initWithBaseURL:baseURL];

	return tagsDatabase;
}

- (ViParser *)parser
{
	return parser;
}

- (void)getMoreBundles:(id)sender
{
	[[ViPreferencesController sharedPreferences] performSelector:@selector(showItem:)
                                                          withObject:@"Bundles"
                                                          afterDelay:0.01];
}

- (void)windowDidResize:(NSNotification *)notification
{
#ifdef TRIAL_VERSION
	if (nagTitle) {
		NSView *view = [[[self window] contentView] superview];
		NSRect rect = [nagTitle frame];
		rect.origin.x = NSMaxX([view frame]) - rect.size.width - 35;
		rect.origin.y = NSMaxY([view frame]) - rect.size.height - (19 - rect.size.height);
		[nagTitle setFrame:rect];
	}
#endif

	[[self window] saveFrameUsingName:@"MainDocumentWindow"];
}

#ifdef TRIAL_VERSION
- (void)metaChanged:(NSNotification *)notification
{
	int left = [[notification object] intValue];
	NSString *s;
	if (left <= 0)
		s = @"Expired evaluation copy";
	else
		s = [NSString stringWithFormat:@"%i day%s remaining", left, left == 1 ? "" : "s"];

	NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
	[attrs setObject:[NSFont titleBarFontOfSize:10.0] forKey:NSFontAttributeName];

	NSColor *c1 = [NSColor grayColor];
	NSColor *c2 = [NSColor redColor];
	NSColor *c;
	if (left >= 8)
		c = c1;
	else
		c = [c2 blendedColorWithFraction:(CGFloat)(left < 0 ? 0 : left)/12.0 ofColor:c1];
	[attrs setObject:c forKey:NSForegroundColorAttributeName];

	NSView *view = [[[self window] contentView] superview];
	NSRect rect;
	rect.size = [s sizeWithAttributes:attrs];
	rect.size.width += 10;
	rect.origin.x = NSMaxX([view frame]) - rect.size.width - 35;
	rect.origin.y = NSMaxY([view frame]) - rect.size.height - (19 - rect.size.height);

	if (nagTitle == nil) {
		nagTitle = [[NSTextField alloc] initWithFrame:rect];
		[nagTitle setDrawsBackground:NO];
		[nagTitle setEditable:NO];
		[nagTitle setBezeled:NO];
		[nagTitle setTextColor:[NSColor blackColor]];
		[view addSubview:nagTitle];
	} else
		[nagTitle setFrame:rect];
	[nagTitle setStringValue:[[NSAttributedString alloc] initWithString:s attributes:attrs]];
}
#endif

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
#ifdef TRIAL_VERSION
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(metaChanged:)
						     name:ViTrialDaysChangedNotification
						   object:nil];
	updateMeta();
#endif

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

	isLoaded = YES;
	if (initialDocument) {
		[self addNewTab:initialDocument];
		initialDocument = nil;
	}
	if (initialViewController) {
		[self createTabWithViewController:initialViewController];
		initialViewController = nil;
	}

	[[self window] bind:@"title" toObject:self withKeyPath:@"currentView.title" options:nil];
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
		[[self project] close];
		project = nil;
		*/
	}

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
		if (viFieldEditor == nil)
			viFieldEditor = [ViTextView makeFieldEditor];
		return viFieldEditor;
	}
	return nil;
}

- (NSApplicationPresentationOptions)window:(NSWindow *)window willUseFullScreenPresentationOptions:(NSApplicationPresentationOptions)proposedOptions
{
	return proposedOptions | NSApplicationPresentationAutoHideToolbar;
}

- (void)windowWillEnterFullScreen:(NSNotification *)notification
{
#ifdef TRIAL_VERSION
	[nagTitle setHidden:YES];
#endif
	[[ViEventManager defaultManager] emit:ViEventWillEnterFullScreen for:self with:self, nil];
}

- (void)windowDidEnterFullScreen:(NSNotification *)notification
{
	[[ViEventManager defaultManager] emit:ViEventDidEnterFullScreen for:self with:self, nil];
}

- (void)windowWillExitFullScreen:(NSNotification *)notification
{
#ifdef TRIAL_VERSION
	[nagTitle setHidden:NO];
#endif
	[[ViEventManager defaultManager] emit:ViEventWillExitFullScreen for:self with:self, nil];
}

- (void)windowDidExitFullScreen:(NSNotification *)notification
{
	[[ViEventManager defaultManager] emit:ViEventDidExitFullScreen for:self with:self, nil];
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

	[documents addObject:document];

	/* Update symbol table. */
	[symbolController filterSymbols];
	[document addObserver:symbolController forKeyPath:@"symbols" options:0 context:NULL];
}

/* Create a new document tab.
 */
- (void)createTabWithViewController:(id<ViViewController>)viewController
{
	if (!isLoaded) {
		/* Defer until NIB is loaded. */
		initialViewController = viewController;
		return;
	}

	ViTabController *tabController = [[ViTabController alloc] initWithViewController:viewController window:[self window]];

	NSTabViewItem *tabItem = [(NSTabViewItem *)[NSTabViewItem alloc] initWithIdentifier:tabController];
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
	ViTabController *lastTabController = [(NSTabViewItem *)[[tabBar representedTabViewItems] lastObject] identifier];
	if ([self currentDocument] != nil &&
	    [[self currentDocument] fileURL] == nil &&
	    [document fileURL] != nil &&
	    ![[self currentDocument] isDocumentEdited] &&
	    [[lastTabController views] count] == 1 &&
	    [[[lastTabController views] objectAtIndex:0] respondsToSelector:@selector(document)] &&
	    [self currentDocument] == [[[lastTabController views] objectAtIndex:0] document]) {
		[tabBar disableAnimations];
		closeThisDocument = [self currentDocument];
	}

	[self addDocument:document];
	if (closeThisDocument == nil && (
	    [[NSUserDefaults standardUserDefaults] boolForKey:@"prefertabs"] ||
	    [tabView numberOfTabViewItems] == 0))
		[self createTabForDocument:document];
	else
		[self switchToDocument:document];

	if (closeThisDocument) {
		[closeThisDocument closeAndWindow:NO];
		[tabBar enableAnimations];
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
	[self checkDocumentsChanged];
}

- (ViDocument *)currentDocument
{
	id<ViViewController> viewController = [self currentView];
	if ([viewController respondsToSelector:@selector(document)])
		return [viewController document];
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

	baseURL = [url absoluteURL];
}

- (void)deferred:(id<ViDeferred>)deferred status:(NSString *)statusMessage
{
	[self message:@"%@", statusMessage];
}

- (void)checkBaseURL:(NSURL *)url onCompletion:(void (^)(NSURL *url, NSError *error))aBlock
{
	id<ViDeferred> deferred = [[ViURLManager defaultManager] fileExistsAtURL:url onCompletion:^(NSURL *normalizedURL, BOOL isDirectory, NSError *error) {
		if (error)
			aBlock(nil, [ViError errorWithFormat:@"%@: %@", [url path], [error localizedDescription]]);
		else if (normalizedURL == nil)
			aBlock(nil, [ViError errorWithFormat:@"%@: no such file or directory", [url path]]);
		else if (!isDirectory)
			aBlock(nil, [ViError errorWithFormat:@"%@: not a directory", [normalizedURL path]]);
		else
			aBlock(normalizedURL, nil);
	}];
	[deferred setDelegate:self];
}

- (NSString *)displayBaseURL
{
	return [baseURL displayString];
}

#pragma mark -
#pragma mark Notification of changes on disk

- (void)alertModifiedDocuments
{
	NSUInteger nmodified = [modifiedSet count];
	if (nmodified == 0)
		return;

	// Choose the most appropriate document from the set of modified documents.
	// Try to minimize the number of document switches.

	ViDocument *document = nil;

	/* Check if the current view contains a modified document. */
	id<ViViewController> viewController = [self currentView];
	if ([viewController respondsToSelector:@selector(document)] &&
	    [modifiedSet containsObject:[viewController document]])
		document = [viewController document];

	/* Check if current tab has a view of a modified document. */
	if (document == nil) {
		ViTabController *tabController = [self selectedTabController];
		for (viewController in [tabController views])
			if ([viewController respondsToSelector:@selector(document)] &&
			    [modifiedSet containsObject:[viewController document]]) {
				document = [viewController document];
				break;
			}
	}

	if (document == nil)
		document = [modifiedSet anyObject];

	[self selectDocument:document];

	NSAlert *alert = [[NSAlert alloc] init];
	if (nmodified == 1)
		[alert setMessageText:[NSString stringWithFormat:@"The document \"%@\", has been changed by another application since you opened or saved it.",
			[[document fileURL] lastPathComponent]]];
	else
		[alert setMessageText:[NSString stringWithFormat:@"The document \"%@\", and %lu other documents, has been changed by another application since you opened or saved it.",
			[[document fileURL] lastPathComponent], nmodified - 1]];
	[alert setInformativeText:@"Do you want to keep the open version or revert to the document on disk?"];
	[alert addButtonWithTitle:[NSString stringWithFormat:@"Revert %@", [[document fileURL] lastPathComponent]]];
	if (nmodified > 1)
		[alert addButtonWithTitle:@"Revert all"];
	[alert addButtonWithTitle:[NSString stringWithFormat:@"Keep %@", [[document fileURL] lastPathComponent]]];
	if (nmodified > 1)
		[alert addButtonWithTitle:@"Keep all"];
	[alert beginSheetModalForWindow:[self window]
			  modalDelegate:self
			 didEndSelector:@selector(documentChangedAlertDidEnd:returnCode:contextInfo:)
			    contextInfo:document];
}

- (void)revertAllModified
{
	ViDocument *document;
	while ((document = [modifiedSet anyObject]) != nil) {
		NSError *error = nil;
		[modifiedSet removeObject:document];
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
	if (state == 0) // alert next modified document
		[self alertModifiedDocuments];
	else if (state == 1) // revert all modified documents
		[self revertAllModified];
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
		[modifiedSet removeObject:document];
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
		} else
			[self alertModifiedDocuments];
	} else if (returnCode == NSAlertSecondButtonReturn && nbuttons == 4) {
		[self revertAllModified];
	} else if ((returnCode == NSAlertThirdButtonReturn && nbuttons == 4) ||
	           (returnCode == NSAlertSecondButtonReturn && nbuttons == 2)) {
		[modifiedSet removeObject:document];
		document.isTemporary = YES;
		[self alertModifiedDocuments];
	} else if (returnCode == NSAlertThirdButtonReturn + 1 && nbuttons == 4) {
		for (document in modifiedSet)
			document.isTemporary = YES;
		modifiedSet = nil;
	}
}

- (void)checkDocumentsChanged
{
	NSMutableSet *deletedSet = [NSMutableSet set];
	modifiedSet = [NSMutableSet set];
	for (ViDocument *document in documents) {
		if (document.isTemporary || ![[document fileURL] isFileURL])
			continue;

		NSError *error = nil;
		NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[[document fileURL] path] error:&error];
		if (error) {
			[document updateChangeCount:NSChangeReadOtherContents];
			document.isTemporary = YES;
			if ([error isFileNotFoundError])
				[deletedSet addObject:document];
			else
				INFO(@"failed to stat %@: %@", [[document fileURL] path], [error localizedDescription]);
		} else {
			NSDate *modificationDate = [attributes fileModificationDate];
			if ([[document fileModificationDate] compare:modificationDate] == NSOrderedAscending) {
				[document updateChangeCount:NSChangeReadOtherContents];
				[modifiedSet addObject:document];
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
		} else
			[alert setMessageText:[NSString stringWithFormat:@"%lu document%s was deleted from disk by another application.",
				ndeleted, pluralS]];
		[alert setInformativeText:[NSString stringWithFormat:@"The document%s remain%s open.", pluralS, ndeleted == 1 ? "s" : ""]];
		[alert beginSheetModalForWindow:[self window]
				  modalDelegate:self
				 didEndSelector:@selector(documentsDeletedAlertDidEnd:returnCode:contextInfo:)
				    contextInfo:nil];
	} else
		[self alertModifiedDocuments];
}

#pragma mark -
#pragma mark Document closing

- (void)documentController:(NSDocumentController *)docController
               didCloseAll:(BOOL)didCloseAll
               contextInfo:(void *)contextInfo
{
	DEBUG(@"force closing all views: %s", didCloseAll ? "YES" : "NO");
	if (!didCloseAll)
		return;

	while ([tabView numberOfTabViewItems] > 0) {
		NSTabViewItem *item = [tabView tabViewItemAtIndex:0];
		ViTabController *tabController = [item identifier];
		[self documentController:[ViDocumentController sharedDocumentController]
			     didCloseAll:YES
			   tabController:tabController];
	}
}

- (BOOL)windowShouldClose:(id)window
{
	DEBUG(@"documents = %@", documents);

#if 0
	/* Close the current document first to avoid unecessary document switching. */
	if ([[self currentDocument] isDocumentEdited]) {
		[[self currentDocument] close];
		if ([documents count] == 0)
			return YES;
	}
#endif

	if ([documents count] == 0)
		return YES;

	NSMutableSet *set = [[NSMutableSet alloc] init];
	for (ViDocument *doc in documents) {
		if ([set containsObject:doc])
			continue;
		if (![doc isDocumentEdited])
			continue;

		/* Check if this document is open in another window. */
		BOOL openElsewhere = NO;
		for (NSWindow *window in [NSApp windows]) {
			ViWindowController *wincon = [window windowController];
			if (wincon == self || ![wincon isKindOfClass:[ViWindowController class]])
				continue;
			if ([[wincon documents] containsObject:doc]) {
				openElsewhere = YES;
				break;
			}
		}

		if (!openElsewhere)
			[set addObject:doc];
	}

	[[ViDocumentController sharedDocumentController] closeAllDocumentsInSet:set
								   withDelegate:self
							    didCloseAllSelector:@selector(documentController:didCloseAll:contextInfo:)
								    contextInfo:window];
	return NO;
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	if (currentWindowController == self)
		currentWindowController = nil;
	DEBUG(@"will close, got documents: %@", documents);
	[[self project] close];
	[windowControllers removeObject:self];
	[tabBar setDelegate:nil];

	ViDocument *doc;
	while ((doc = [documents lastObject]) != nil)
		[self unlistDocument:doc];

	[[ViEventManager defaultManager] clearFor:self];
}

- (id<ViViewController>)currentView;
{
	return currentView;
}

- (void)setCurrentView:(id<ViViewController>)viewController
{
	if ([currentView respondsToSelector:@selector(document)])
		previousDocumentView = currentView;
	currentView = viewController;
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
#ifndef NO_DEBUG
		if ([[tabController views] count] > 0)
			DEBUG(@"WARNING: got %lu views left in tab", [[tabController views] count]);
#endif
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
	id<ViViewController> viewController = [self currentView];

	/* If the current view is a document view, check if it's the last document view. */
	if ([viewController respondsToSelector:@selector(document)]) {
		ViDocument *doc = [viewController document];

		/* Check if this document is open in another window. */
		BOOL openElsewhere = NO;
		for (NSWindow *window in [NSApp windows]) {
			ViWindowController *wincon = [window windowController];
			if (wincon == self || ![wincon isKindOfClass:[ViWindowController class]])
				continue;
			if ([[wincon documents] containsObject:doc]) {
				openElsewhere = YES;
				break;
			}
		}

		if (!openElsewhere && [[doc views] count] == 1) {
			[doc canCloseDocumentWithDelegate:self
				      shouldCloseSelector:@selector(document:shouldClose:contextInfo:)
					      contextInfo:(void *)(intptr_t)1];
			return;
		}
	}

	[self closeDocumentView:viewController
	       canCloseDocument:YES
		 canCloseWindow:YES];
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
	ViDocumentView *docView = [self currentView];
	if ([tabView numberOfTabViewItems] > 1 || [[[docView tabController] views] count] > 1) {
		[self closeDocumentView:docView
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
	[documents removeObject:document];
	[document closeWindowController:self];
	[document removeObserver:symbolController forKeyPath:@"symbols"];
	[[symbolController nextRunloop] symbolsUpdate:nil];
}

- (ViDocument *)previouslyActiveDocument
{
	DEBUG(@"returning previously active document (currently %@)", [self currentDocument]);
	__block ViDocument *doc = nil;
	[jumpList enumerateJumpsBackwardsUsingBlock:^(ViJump *jump, BOOL *stop) {
		doc = [self documentForURL:jump.url];
		if (doc)
			*stop = YES;
	}];
	return doc ?: [documents lastObject];
}

- (void)closeDocumentView:(id<ViViewController>)viewController
	 canCloseDocument:(BOOL)canCloseDocument
	   canCloseWindow:(BOOL)canCloseWindow
{
	DEBUG(@"closing view controller %@, and document: %s, and window: %s, from window %@",
		viewController, canCloseDocument ? "YES" : "NO", canCloseWindow ? "YES" : "NO",
		[self window]);

	if (viewController == nil)
		[[self window] close];

	if (viewController == currentView)
		[self setCurrentView:nil];

	[[viewController tabController] closeView:viewController];

	/* If this was the last view of the document, close the document too. */
	if (canCloseDocument && [viewController isKindOfClass:[ViDocumentView class]]) {
		ViDocument *doc = [(ViDocumentView *)viewController document];
		/* Check if this document is open in another window. */
		BOOL openElsewhere = NO;
		for (NSWindow *window in [NSApp windows]) {
			ViWindowController *wincon = [window windowController];
			if (wincon == self || ![wincon isKindOfClass:[ViWindowController class]])
				continue;
			if ([[wincon documents] containsObject:doc]) {
				openElsewhere = YES;
				break;
			}
		}

		if (openElsewhere) {
			DEBUG(@"document %@ open in other windows", doc);
			[self unlistDocument:doc];
		} else {
			if ([[doc views] count] == 0) {
				DEBUG(@"closed last view of document %@, closing document", doc);
				[doc close];
			} else {
				DEBUG(@"document %@ has more views open", doc);
			}
		}
	}

	/* If this was the last view in the tab, close the tab too. */
	ViTabController *tabController = [viewController tabController];
	if ([[tabController views] count] == 0) {
		if ([tabView numberOfTabViewItems] == 1)
			[tabBar disableAnimations];

		ViDocument *prevdoc = [self previouslyActiveDocument];
		BOOL preJumping = jumping;
		jumping = NO;
		[self closeTabController:tabController];
		jumping = preJumping;

		if ([tabView numberOfTabViewItems] == 0) {
			DEBUG(@"closed last tab, got documents: %@", documents);
			if ([documents count] > 0)
				[self selectDocument:prevdoc];
			else if (canCloseWindow)
				[[self window] close];
			else {
				ViDocument *newDoc = [[ViDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:NO
															       error:nil];
				newDoc.isTemporary = YES;
				[newDoc addWindowController:self];
				[self addDocument:newDoc];
				[self selectDocumentView:[self createTabForDocument:newDoc]];
			}
		} else
			[self selectDocument:prevdoc];
		[tabBar enableAnimations];
	} else if (tabController == [self selectedTabController]) {
		// Select another document view.
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
		if ([[docView tabController] window] == [self window])
			[set addObject:docView];
	}

	DEBUG(@"closing remaining views in window %@: %@", [self window], set);
	for (docView in set)
		[self closeDocumentView:docView
		       canCloseDocument:NO
			 canCloseWindow:canCloseWindow];
}

- (void)documentController:(NSDocumentController *)docController
	       didCloseAll:(BOOL)didCloseAll
	     tabController:(void *)tabController
{
	DEBUG(@"force close all views in tab %@: %s", tabController, didCloseAll ? "YES" : "NO");
	if (didCloseAll) {
		/* Close any views left in this tab. Do not ask for confirmation. */
		while ([[(ViTabController *)tabController views] count] > 0)
			[self closeDocumentView:[[(ViTabController *)tabController views] objectAtIndex:0]
			       canCloseDocument:YES
				 canCloseWindow:YES];
	}
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

	NSMutableSet *set = [[NSMutableSet alloc] init];

	DEBUG(@"closing tab controller %@", tabController);

	/* If closing the last tab, close the window. */
	if ([tabView numberOfTabViewItems] == 1) {
		[[self window] performClose:nil];
		return NO;
	}

	/* Close all documents in this tab. */
	id<ViViewController> viewController;
	for (viewController in [tabController views]) {
		if ([viewController respondsToSelector:@selector(document)]) {
			if ([set containsObject:[viewController document]])
				continue;
			if (![[viewController document] isDocumentEdited])
				continue;

			id<ViViewController> otherDocView;
			for (otherDocView in [[viewController document] views])
				if ([otherDocView tabController] != tabController)
					break;
			if (otherDocView != nil)
				continue;

			[set addObject:[viewController document]];
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
	ViTabController *tabController = [tabViewItem identifier];
	[[ViEventManager defaultManager] clearFor:tabController];
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
	id<ViViewController> viewController = [self viewControllerForView:view];
	if (viewController) {
		if (parser.partial) {
			[self message:@"Vi command interrupted."];
			[parser reset];
		}
		[self didSelectViewController:viewController];
	}

	if (ex_modal && view != statusbar) {
		[NSApp abortModal];
		ex_modal = NO;
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

- (void)didSelectViewController:(id<ViViewController>)viewController
{
	DEBUG(@"did select view %@", viewController);

	if (viewController == [self currentView])
		return;

	[[ViEventManager defaultManager] emit:ViEventWillSelectView for:self with:self, viewController, nil];

	/* Update the previous document pointer. */
	id<ViViewController> prevView = [self currentView];
	if ([prevView isKindOfClass:[ViDocumentView class]]) {
		ViDocument *doc = [(ViDocumentView *)prevView document];
		if (doc != previousDocument) {
			DEBUG(@"previous document %@ -> %@", previousDocument, doc);
			previousDocument = doc;
		}
	}

	if ([viewController isKindOfClass:[ViDocumentView class]]) {
		ViDocumentView *docView = viewController;
		if (!jumping)
			[[docView textView] pushCurrentLocationOnJumpList];
		[self didSelectDocument:[docView document]];
		[symbolController updateSelectedSymbolForLocation:[[docView textView] caret]];
	}

	ViTabController *tabController = [viewController tabController];
	[tabController setSelectedView:viewController];

	if (tabController == [currentView tabController] &&
	    currentView != [tabController previousView]) {
		[tabController setPreviousView:currentView];
	}

	[self setCurrentView:viewController];

	[[ViEventManager defaultManager] emit:ViEventDidSelectView for:self with:self, viewController, nil];
}

/*
 * Selects the tab holding the given document view and focuses the view.
 */
- (id<ViViewController>)selectDocumentView:(id<ViViewController>)viewController
{
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
	ViTabController *tabController = [self selectedTabController];
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
	if ([document respondsToSelector:@selector(viewsw)] && [[document views] count] > 0) {
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
 */
- (ViDocumentView *)selectDocument:(ViDocument *)document
{
	if (!isLoaded || document == nil)
		return nil;

	ViDocumentView *docView = [self viewForDocument:document];
	if (docView)
		return [self selectDocumentView:docView];

	/* No view exists of the document, create a new tab. */
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"prefertabs"] ||
	    [tabView numberOfTabViewItems] == 0)
		docView = [self createTabForDocument:document];
	else
		docView = [self switchToDocument:document];
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

- (id<ViViewController>)switchToDocument:(ViDocument *)doc
{
	if (doc == nil)
		return nil;

	if ([[self currentView] isKindOfClass:[ViDocumentView class]] &&
	    [[(ViDocumentView *)[self currentView] document] isEqual:doc])
		return [self currentView];

	ViTabController *tabController = [self selectedTabController];
	id<ViViewController> viewController = [tabController replaceView:[self currentView]
							    withDocument:doc];
	return [self selectDocumentView:viewController];
}

- (void)switchToLastDocument
{
	/* Make sure the previous document is still registered in the document controller. */
	if (previousDocument == nil)
		return;
	if (![[[ViDocumentController sharedDocumentController] documents] containsObject:previousDocument]) {
		DEBUG(@"previous document %@ not listed", previousDocument);
		previousDocument = [[ViDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[previousDocument fileURL]
													  display:NO
													    error:nil];
	}
	[self switchToDocument:previousDocument];
}

- (void)selectLastDocument
{
	if (previousDocument == nil)
		return;
	if (![[[ViDocumentController sharedDocumentController] documents] containsObject:previousDocument]) {
		DEBUG(@"previous document %@ not listed", previousDocument);
		previousDocument = [[ViDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[previousDocument fileURL]
													  display:NO
													    error:nil];
	}
	[self selectDocument:previousDocument];
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
		[self switchToDocument:doc];
}

- (ViDocument *)documentForURL:(NSURL *)url
{
	for (ViDocument *doc in documents)
		if ([url isEqual:[doc fileURL]])
			return doc;
	return nil;
}

- (void)gotoMark:(ViMark *)mark inView:(ViDocumentView *)docView
{
	NSRange range = mark.range;
	ViTextView *textView = [docView textView];
	[textView setCaret:range.location];
	[textView scrollRangeToVisible:range];
	[[textView nextRunloop] showFindIndicatorForRange:range];
}

- (void)gotoMark:(ViMark *)mark
{
	id<ViViewController> viewController = [self currentView];
	if ([viewController isKindOfClass:[ViDocumentView class]])
		[[(ViDocumentView *)viewController textView] pushCurrentLocationOnJumpList];

	if (mark.document) {
		/* XXX: prevent pushing an extraneous jump on the list. */
		// jumping = YES;
		id<ViViewController> viewController = [self selectDocument:mark.document];
		// jumping = NO;

		[self gotoMark:mark inView:viewController];
	} else if (mark.url)
		[self gotoURL:mark.url line:mark.line column:mark.column];
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
		ViTabController *tabController = [viewController tabController];
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
		ViTabController *tabController = [viewController tabController];
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

	ViTabController *tabController = [viewController tabController];
	[tabController normalizeAllViews];
	return YES;
}

- (BOOL)closeOtherViews
{
	id<ViViewController> viewController = [self currentView];
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
	id<ViViewController> viewController = [self currentView];
	if (viewController == nil)
		return NO;

	ViTabController *tabController = [viewController tabController];
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

- (id<ViViewController>)splitVertically:(BOOL)isVertical
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
				       relativeTo:baseURL
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
		[doc addWindowController:self];
		[self addDocument:doc];

		id<ViViewController> viewController = [self currentView];
		ViTabController *tabController = [viewController tabController];
		ViDocumentView *newDocView = nil;
		if (allowReusedView && !newDoc) {
			/* Check if the tab already has a view for this document. */
			for (id<ViViewController> v in tabController.views)
				if ([v respondsToSelector:@selector(document)] &&
				    [v document] == doc) {
					newDocView = v;
					break;
				}
		}
		if (newDocView == nil) {
			if (tabController == nil) {
				newDocView = [self createTabForDocument:doc];
			} else {
				newDocView = [tabController splitView:viewController
							     withView:[doc makeView]
							   vertically:isVertical];
			}
		}
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

		return newDocView;
	}

	return nil;
}

- (id<ViViewController>)splitVertically:(BOOL)isVertical
                                andOpen:(id)filenameOrURL
{
	return [self splitVertically:isVertical
			     andOpen:filenameOrURL
		  orSwitchToDocument:nil
		     allowReusedView:YES];
}

- (id<ViViewController>)splitVertically:(BOOL)isVertical
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
	ViRegexp *rx = [[ViRegexp alloc] initWithString:pattern
						options:ONIG_OPTION_IGNORECASE];

	NSMutableArray *syms = [NSMutableArray array];
	for (ViDocument *doc in documents)
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

- (BOOL)window_last:(ViCommand *)command
{
	ViTabController *tabController = [[self currentView] tabController];
	id<ViViewController> prevView = tabController.previousView;
	if (prevView == nil)
		return NO;
	[self selectDocumentView:prevView];
	return YES;
}

- (BOOL)window_next:(ViCommand *)command
{
	ViTabController *tabController = [[self currentView] tabController];
	id<ViViewController> nextView = [tabController nextViewClockwise:YES
							      relativeTo:[[self currentView] view]];
	if (nextView == nil)
		return NO;
	[self selectDocumentView:nextView];
	return YES;
}

- (BOOL)window_previous:(ViCommand *)command
{
	ViTabController *tabController = [[self currentView] tabController];
	id<ViViewController> nextView = [tabController nextViewClockwise:NO
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
	DEBUG(@"previous document is %@", previousDocument);

	// Update jumplist
	NSView *view = [[self currentView] innerView];
	if ([view respondsToSelector:@selector(pushCurrentLocationOnJumpList)])
		[(ViTextView *)view pushCurrentLocationOnJumpList];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"prefertabs"])
		[self selectLastDocument];
	else
		[self switchToLastDocument];
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
		exString = exCommand;
		if (ex_modal)
			[NSApp abortModal];
	} else if (ex_modal)
		[NSApp abortModal];

	ex_busy = NO;
}

- (NSString *)getExStringInteractivelyForCommand:(ViCommand *)command prefix:(NSString *)prefix
{
	ViMacro *macro = command.macro;

	if (ex_busy) {
		INFO(@"%s", "can't handle nested ex commands!");
		return nil;
	}

	ex_busy = YES;
	exString = nil;

	[messageField setHidden:YES];
	[statusbar setHidden:NO];
	[statusbar setSelectable:NO];
	[statusbar setEditable:YES];
	[statusbar setStringValue:@""];
	[statusbar setFont:[NSFont userFixedPitchFontOfSize:12]];
	/*
	 * The ExTextField resets the field editor when gaining focus (in becomeFirstResponder).
	 */
	[[self window] makeFirstResponder:statusbar];

	ViTextView *editor = (ViTextView *)[[self window] fieldEditor:YES forObject:statusbar];
	[editor setString:prefix ?: @""];
	[editor setCaret:[[editor textStorage] length]];

	if (macro) {
		NSInteger keyCode;
		while (ex_busy && (keyCode = [macro pop]) != -1)
			[editor.keyManager handleKey:keyCode];
	}

	if (ex_busy) {
		ex_modal = YES;
		[NSApp runModalForWindow:[self window]];
		ex_modal = NO;
		ex_busy = NO;
	}

	[statusbar setStringValue:@""];
	[statusbar setEditable:NO];
	[statusbar setHidden:YES];
	[messageField setHidden:NO];
	[self focusEditor];

	return exString;
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
									 relativeTo:baseURL
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
	id<ViViewController> viewController = nil;

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
					[[doc nextRunloop] makeWindowControllers];
				} else {
					[doc addWindowController:self];
					[self addDocument:doc];
					viewController = [self switchToDocument:doc];
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
			[doc addWindowController:self];
			[self addDocument:doc];
			ViDocumentView *docView = [self createTabForDocument:doc];
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
	if ([command.mapping.name hasPrefix:@"b"]) {
		if ([self currentDocument] != doc)
			[self switchToDocument:doc];
	} else if ([command.mapping.name isEqualToString:@"tbuffer"]) {
		ViDocumentView *docView = [self viewForDocument:doc];
		if (docView == nil)
			[self createTabForDocument:doc];
		else
			[self selectDocumentView:docView];
	} else
		/* otherwise it's either sbuffer or vbuffer */
		[self splitVertically:[command.mapping.name isEqualToString:@"vbuffer"]
                              andOpen:nil
                   orSwitchToDocument:doc
                      allowReusedView:NO];

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
	    @"autocollapse", @"hidetab", @"showguide", @"searchincr", @"smartindent",
	    @"wrap", @"antialias", @"list", @"smarttab", @"prefertabs", @"cursorline", @"gdefault",
	    @"wrapscan", @"clipboard", @"matchparen", @"flashparen", @"linebreak",
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
	id<ViViewController> viewController = [self currentView];
	if ([tabView numberOfTabViewItems] > 1 || [[[[self currentView] tabController] views] count] > 1) {
		[self closeDocumentView:viewController
		       canCloseDocument:NO
			 canCloseWindow:NO];
	} else if (command.force) {
		ViDocument *doc;
		while ((doc = [documents lastObject]) != nil) {
			/* Check if this document is open in another window. */
			BOOL openElsewhere = NO;
			for (NSWindow *window in [NSApp windows]) {
				ViWindowController *wincon = [window windowController];
				if (wincon == self || ![wincon isKindOfClass:[ViWindowController class]])
					continue;
				if ([[wincon documents] containsObject:doc]) {
					openElsewhere = YES;
					break;
				}
			}

			if (openElsewhere)
				[self unlistDocument:doc];
			else
				[doc closeAndWindow:YES];
		}
		[[self window] close];
	} else
		[[self window] performClose:nil];

	// FIXME: quit/hide app if last window?
	return nil;
}

@end

