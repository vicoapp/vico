#import "ProjectDelegate.h"
#import "logging.h"
#import "MHTextIconCell.h"
#import "ViWindowController.h"
#import "ExEnvironment.h"
#import "ViError.h"
#import "NSString-additions.h"
#import "ViDocumentController.h"
#import "ViURLManager.h"
#import "ViCompletion.h"
#import "ViCompletionController.h"

@interface ProjectDelegate (private)
- (void)recursivelySortProjectFiles:(NSMutableArray *)children;
- (NSString *)relativePathForItem:(NSDictionary *)item;
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item;
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item;
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)anIndex ofItem:(id)item;
- (void)expandNextItem:(id)dummy;
- (void)expandItems:(NSArray *)items recursionLimit:(int)recursionLimit;
- (void)sortProjectFiles:(NSMutableArray *)children;
- (BOOL)rescan_files:(ViCommand *)command;
- (NSMutableArray *)filteredContents:(NSArray *)contents ofDirectory:(NSURL *)url;
- (void)resetExpandedItems;
- (id)findItemWithURL:(NSURL *)aURL inItems:(NSArray *)items;
- (void)rescanURL:(NSURL *)aURL
       ifExpanded:(BOOL)ifExpandedFlag
     andSelectURL:(NSURL *)selectedURL
	   rename:(BOOL)renameFlag;
- (void)rescanURL:(NSURL *)aURL;
- (void)selectURL:(NSURL *)aURL;
- (void)pauseEvents;
- (void)resumeEvents;
@end

@implementation ProjectFile

@synthesize score, markedString, url, children;

- (id)initWithURL:(NSURL *)aURL attributes:(NSDictionary *)aDictionary
{
	self = [super init];
	if (self) {
		url = aURL;
		attributes = aDictionary;
	}
	return self;
}

+ (id)fileWithURL:(NSURL *)aURL attributes:(NSDictionary *)aDictionary
{
	return [[ProjectFile alloc] initWithURL:aURL attributes:aDictionary];
}

- (BOOL)isDirectory
{
	return [[attributes fileType] isEqualToString:NSFileTypeDirectory];
}

- (BOOL)hasCachedChildren
{
	return children != nil;
}

- (NSString *)name
{
	if ([url isFileURL])
		return [[NSFileManager defaultManager] displayNameAtPath:[url path]];
	else
		return [url lastPathComponent];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ProjectFile: %@>", url];
}

@end

@implementation ProjectDelegate

@synthesize delegate;

- (id)init
{
	self = [super init];
	if (self) {
		history = [[ViJumpList alloc] init];
		[history setDelegate:self];
		font = [NSFont systemFontOfSize:11.0];
		expandedSet = [NSMutableSet set];
	}
	return self;
}

- (void)finalize
{
	[self stopEvents];
}

- (void)awakeFromNib
{
	explorer.keyManager = [[ViKeyManager alloc] initWithTarget:self
							defaultMap:[ViMap explorerMap]];
	[explorer setTarget:self];
	[explorer setDoubleAction:@selector(explorerDoubleClick:)];
	[explorer setAction:@selector(explorerClick:)];
	[[sftpConnectForm cellAtIndex:1] setPlaceholderString:NSUserName()];
	[rootButton setTarget:self];
	[rootButton setAction:@selector(changeRoot:)];
	[actionButtonCell setImage:[NSImage imageNamed:@"actionmenu"]];
	[actionButton setMenu:actionMenu];

	[[NSUserDefaults standardUserDefaults] addObserver:self
						forKeyPath:@"explorecaseignore"
						   options:NSKeyValueObservingOptionNew
						   context:NULL];
	[[NSUserDefaults standardUserDefaults] addObserver:self
						forKeyPath:@"exploresortfolders"
						   options:NSKeyValueObservingOptionNew
						   context:NULL];

	[self browseURL:[environment baseURL]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
		      ofObject:(id)object
			change:(NSDictionary *)change
		       context:(void *)context
{
	/* only explorecaseignore and exploresortfolders options observed */
	/* re-sort explorer */
	if (rootItems) {
		[self recursivelySortProjectFiles:rootItems];
		if (!isFiltered)
			[self filterFiles:self];
	}
}

- (void)changeRoot:(id)sender
{
	[self browseURL:[[sender clickedPathComponentCell] URL]];
}

- (NSMutableArray *)filteredContents:(NSArray *)files ofDirectory:(NSURL *)url
{
	if (files == nil)
		return nil;

	NSMutableArray *children = [NSMutableArray array];
	for (NSArray *entry in files) {
		NSString *filename = [entry objectAtIndex:0];
		NSDictionary *attributes = [entry objectAtIndex:1];
		if (![filename hasPrefix:@"."] && [skipRegex matchInString:filename] == nil) {
			NSURL *curl = [url URLByAppendingPathComponent:filename];
			if ([curl isFileURL]) {
				/*
				 * XXX: resolve symlinks for all URL types!
				 */
				NSURL *symurl = [curl URLByResolvingSymlinksInPath];
				attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[symurl path] error:nil];
			}
			ProjectFile *pf = [ProjectFile fileWithURL:curl attributes:attributes];
			if ([pf isDirectory]) {
				NSArray *contents = [[ViURLManager defaultManager] cachedContentsOfDirectoryAtURL:pf.url];
				pf.children = [self filteredContents:contents ofDirectory:pf.url];
			}
			[children addObject:pf];
		}
	}

	[self sortProjectFiles:children];

	return children;
}

- (void)childrenAtURL:(NSURL *)url onCompletion:(void (^)(NSMutableArray *children, NSError *error))aBlock
{
	ViURLManager *um = [ViURLManager defaultManager];

	id<ViDeferred> deferred = [um contentsOfDirectoryAtURL:url onCompletion:^(NSArray *files, NSError *error) {
		[progressIndicator setHidden:YES];
		[progressIndicator stopAnimation:nil];
		if (error) {
			INFO(@"failed to read contents of folder %@", url);
			aBlock(nil, error);
		} else {
			NSMutableArray *children = [self filteredContents:files ofDirectory:url];
			aBlock(children, nil);
		}
	}];

	if (deferred) {
		[progressIndicator setHidden:NO];
		[progressIndicator startAnimation:nil];
	}
}

- (void)sortProjectFiles:(NSMutableArray *)children
{
	BOOL sortFolders = [[NSUserDefaults standardUserDefaults] boolForKey:@"exploresortfolders"];
	BOOL caseIgnoreSort = [[NSUserDefaults standardUserDefaults] boolForKey:@"explorecaseignore"];

	NSStringCompareOptions sortOptions = 0;
	if (caseIgnoreSort)
		sortOptions = NSCaseInsensitiveSearch;

	[children sortUsingComparator:^(id obj1, id obj2) {
		if (sortFolders) {
			if ([obj1 isDirectory]) {
				if (![obj2 isDirectory])
					return (NSComparisonResult)NSOrderedAscending;
			} else if ([obj2 isDirectory])
				return (NSComparisonResult)NSOrderedDescending;
		}
		return [[obj1 name] compare:[obj2 name] options:sortOptions];
	}];
}

- (void)recursivelySortProjectFiles:(NSMutableArray *)children
{
	[self sortProjectFiles:children];

	for (ProjectFile *file in children)
		if ([file hasCachedChildren] && [file isDirectory])
			[self recursivelySortProjectFiles:[file children]];
}

- (void)stopEvents
{
	if (evstream) {
		FSEventStreamStop(evstream);
		FSEventStreamUnscheduleFromRunLoop(evstream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
		FSEventStreamInvalidate(evstream);
		FSEventStreamRelease(evstream);
		evstream = NULL;
	}
}

- (void)pauseEvents
{
	if (evstream)
		FSEventStreamStop(evstream);
}

- (void)resumeEvents
{
	if (evstream)
		FSEventStreamStart(evstream);
}

- (BOOL)isEditing
{
	return [explorer editedRow] != -1;
}

void mycallback(
    ConstFSEventStreamRef streamRef,
    void *clientCallBackInfo,
    size_t numEvents,
    void *eventPaths,
    const FSEventStreamEventFlags eventFlags[],
    const FSEventStreamEventId eventIds[])
{
	int i;
	char **paths = eventPaths;
	ProjectDelegate *explorer = clientCallBackInfo;

	if ([explorer isEditing]) {
		DEBUG(@"ignoring %lu events while editing", numEvents);
		return;
	}

	for (i = 0; i < numEvents; i++) {
		NSString *path = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:paths[i] length:strlen(paths[i])];
		NSURL *url = [NSURL fileURLWithPath:path];
		[explorer rescanURL:url ifExpanded:YES andSelectURL:nil rename:NO];
	}
}

- (void)startEvents:(NSURL *)aURL
{
	if (![aURL isFileURL])
		return;

	CFStringRef mypath = (CFStringRef)[aURL path];
	CFArrayRef pathsToWatch = CFArrayCreate(NULL, (const void **)&mypath, 1, NULL);
	CFAbsoluteTime latency = 1.0; /* Latency in seconds */

	struct FSEventStreamContext ctx;
	bzero(&ctx, sizeof(ctx));
	ctx.info = self;

	evstream = FSEventStreamCreate(NULL,
		&mycallback,
		&ctx,
		pathsToWatch,
		kFSEventStreamEventIdSinceNow,
		latency,
		kFSEventStreamCreateFlagWatchRoot
	);

	 /* Create the stream before calling this. */
	FSEventStreamScheduleWithRunLoop(evstream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);

	FSEventStreamStart(evstream);
}

- (void)browseURL:(NSURL *)aURL andDisplay:(BOOL)display jump:(BOOL)jump
{
	skipRegex = [[ViRegexp alloc] initWithString:[[NSUserDefaults standardUserDefaults] stringForKey:@"skipPattern"]];

	[self stopEvents];
	[self childrenAtURL:aURL onCompletion:^(NSMutableArray *children, NSError *error) {
		if (error) {
			NSAlert *alert = [NSAlert alertWithError:error];
			[alert runModal];
		} else {
			if (jump)
				[history pushURL:[rootButton URL] line:0 column:0 view:nil];
			if (display)
				[self openExplorerTemporarily:NO];
			rootItems = children;
			[self filterFiles:self];
			[explorer reloadData];
			[self resetExpandedItems];
			[rootButton setURL:aURL];
			[environment setBaseURL:aURL];
			[self startEvents:aURL];

			if (!jump)
				[explorer selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
				      byExtendingSelection:NO];
		}
	}];

	explorer.lastSelectedRow = 0;
}

- (void)browseURL:(NSURL *)aURL andDisplay:(BOOL)display
{
	[self browseURL:aURL andDisplay:display jump:YES];
}

- (void)browseURL:(NSURL *)aURL
{
	[self browseURL:aURL andDisplay:YES jump:YES];
}

#pragma mark -
#pragma mark ViJumpList delegate

- (void)jumpList:(ViJumpList *)aJumpList goto:(ViJump *)jump
{
	[self browseURL:[jump url] andDisplay:YES jump:NO];
}

- (void)jumpList:(ViJumpList *)aJumpList added:(ViJump *)jump
{
	DEBUG(@"added jump %@", jump);
}

/* syntax: [count]<ctrl-i> */
- (BOOL)jumplist_forward:(ViCommand *)command
{
	return [history forwardToURL:NULL line:NULL column:NULL view:NULL];
}

/* syntax: [count]<ctrl-o> */
- (BOOL)jumplist_backward:(ViCommand *)command
{
	NSURL *url = [rootButton URL];
	NSUInteger zero = 0;
	NSView *view = nil;
	return [history backwardToURL:&url line:&zero column:&zero view:&view];
}

#pragma mark -
#pragma mark Explorer actions

- (IBAction)actionMenu:(id)sender
{
	NSPoint p = NSMakePoint(0, 0);
	NSIndexSet *set = [explorer selectedRowIndexes];
	if ([set count] > 0)
		p = [explorer rectOfRow:[set firstIndex]].origin;
	NSEvent *ev = [NSEvent mouseEventWithType:NSLeftMouseDown
	                                 location:[explorer convertPoint:p toView:nil]
	                            modifierFlags:0
	                                timestamp:1
	                             windowNumber:[window windowNumber]
	                                  context:[NSGraphicsContext currentContext]
	                              eventNumber:1
	                               clickCount:1
	                                 pressure:0.0];
	[NSMenu popUpContextMenu:actionMenu withEvent:ev forView:sender];
}

- (void)sftpSheetDidEnd:(NSWindow *)sheet
             returnCode:(int)returnCode
            contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
}

- (IBAction)acceptSftpSheet:(id)sender
{
	if ([[[sftpConnectForm cellAtIndex:0] stringValue] length] == 0) {
		NSBeep();
		[sftpConnectForm selectTextAtIndex:0];
		return;
	}
	[NSApp endSheet:sftpConnectView];
	NSString *host = [[sftpConnectForm cellAtIndex:0] stringValue];
	NSString *user = [[sftpConnectForm cellAtIndex:1] stringValue];	/* might be blank */
	NSString *path = [[sftpConnectForm cellAtIndex:2] stringValue];

	if (![path hasPrefix:@"/"])
		path = [NSString stringWithFormat:@"/~/%@", path];
	NSURL *url;
	path = [path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	if ([user length] > 0)
		url = [NSURL URLWithString:[NSString stringWithFormat:@"sftp://%@@%@%@", user, host, path]];
	else
		url = [NSURL URLWithString:[NSString stringWithFormat:@"sftp://%@%@", host, path]];
	[self browseURL:url];
}

- (IBAction)cancelSftpSheet:(id)sender
{
	[NSApp endSheet:sftpConnectView];
}

- (IBAction)addSFTPLocation:(id)sender
{
	[NSApp beginSheet:sftpConnectView
	   modalForWindow:window
	    modalDelegate:self
	   didEndSelector:@selector(sftpSheetDidEnd:returnCode:contextInfo:)
	      contextInfo:nil];
}

- (NSIndexSet *)clickedIndexes
{
	NSIndexSet *set = [explorer selectedRowIndexes];
	NSInteger clickedRow = [explorer clickedRow];
	if (clickedRow != -1 && ![set containsIndex:clickedRow])
		set = [NSIndexSet indexSetWithIndex:clickedRow];
	return set;
}

- (IBAction)openDocuments:(id)sender
{
	__block BOOL didOpen = NO;
	NSIndexSet *set = [self clickedIndexes];
	[set enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		ProjectFile *pf;
		id item = [explorer itemAtRow:idx];
		if ([item isKindOfClass:[ViCompletion class]])
			pf = [(ViCompletion *)item representedObject];
		else
			pf = item;
		if (pf && ![self outlineView:explorer isItemExpandable:item]) {
			[delegate gotoURL:[pf url]];
			didOpen = YES;
		}
	}];

	if (didOpen)
		[self cancelExplorer];
}

- (IBAction)openInTab:(id)sender
{
	__block BOOL didOpen = NO;
	NSIndexSet *set = [self clickedIndexes];
	[set enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		ProjectFile *pf;
		id item = [explorer itemAtRow:idx];
		if ([item isKindOfClass:[ViCompletion class]])
			pf = [(ViCompletion *)item representedObject];
		else
			pf = item;
		if (pf && ![self outlineView:explorer isItemExpandable:item]) {
			NSError *err = nil;
			ViDocument *doc = [[ViDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[pf url]
														 display:NO
														   error:&err];
			if (err)
				[windowController message:@"%@: %@", [pf url], [err localizedDescription]];
			else if (doc) {
				[windowController createTabForDocument:doc];
				didOpen = YES;
			}
		}
	}];

	if (didOpen)
		[self cancelExplorer];
}

- (IBAction)openInCurrentView:(id)sender
{
	NSUInteger idx = [[self clickedIndexes] firstIndex];
	id item = [explorer itemAtRow:idx];
	if (item == nil || [self outlineView:explorer isItemExpandable:item])
		return;
	ProjectFile *pf;
	if ([item isKindOfClass:[ViCompletion class]])
		pf = [(ViCompletion *)item representedObject];
	else
		pf = item;
	if (!pf)
		return;
	NSError *err = nil;
	ViDocument *doc = [[ViDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[pf url]
												 display:NO
												   error:&err];

	if (err)
		[windowController message:@"%@: %@", [pf url], [err localizedDescription]];
	else if (doc)
		[windowController switchToDocument:doc];
	[self cancelExplorer];
}

- (IBAction)openInSplit:(id)sender
{
	__block BOOL didOpen = NO;
	NSIndexSet *set = [self clickedIndexes];
	[set enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		ProjectFile *pf;
		id item = [explorer itemAtRow:idx];
		if ([item isKindOfClass:[ViCompletion class]])
			pf = [(ViCompletion *)item representedObject];
		else
			pf = item;
		if (pf && ![self outlineView:explorer isItemExpandable:item]) {
			[windowController splitVertically:NO
						  andOpen:[pf url]
				       orSwitchToDocument:nil];
			didOpen = YES;
		}
	}];

	if (didOpen)
		[self cancelExplorer];
}

- (IBAction)openInVerticalSplit:(id)sender;
{
	__block BOOL didOpen = NO;
	NSIndexSet *set = [self clickedIndexes];
	[set enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		ProjectFile *pf;
		id item = [explorer itemAtRow:idx];
		if ([item isKindOfClass:[ViCompletion class]])
			pf = [(ViCompletion *)item representedObject];
		else
			pf = item;
		if (item && ![self outlineView:explorer isItemExpandable:item]) {
			[windowController splitVertically:YES
						  andOpen:[item url]
				       orSwitchToDocument:nil];
			didOpen = YES;
		}
	}];

	if (didOpen)
		[self cancelExplorer];
}

- (IBAction)renameFile:(id)sender
{
	NSIndexSet *set = [self clickedIndexes];
	NSInteger row = [set firstIndex];
	[self pauseEvents];
	[explorer selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	[explorer editColumn:0 row:row withEvent:nil select:YES];
}

- (void)removeAlertDidEnd:(NSAlert *)alert
               returnCode:(NSInteger)returnCode
              contextInfo:(void *)contextInfo
{
	if (returnCode != NSAlertFirstButtonReturn)
		return;

	NSArray *urls = contextInfo;

	[[ViURLManager defaultManager] removeItemsAtURLs:urls onCompletion:^(NSError *error) {
		if (error != nil)
			[NSApp presentError:error];

		NSMutableSet *set = [NSMutableSet set];
		for (NSURL *url in urls) {
			id item = [self findItemWithURL:url inItems:rootItems];
			id parent = [explorer parentForItem:item];
			if (parent == nil)
				[set addObject:[rootButton URL]];
			else
				[set addObject:[parent url]];
		}

		for (NSURL *url in set)
			[self rescanURL:url ifExpanded:YES andSelectURL:nil rename:NO];
	}];
}

- (IBAction)removeFiles:(id)sender
{
	__block NSMutableArray *urls = [[NSMutableArray alloc] init];
	NSIndexSet *set = [self clickedIndexes];
	[set enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		ProjectFile *pf;
		id item = [explorer itemAtRow:idx];
		if ([item isKindOfClass:[ViCompletion class]])
			pf = [(ViCompletion *)item representedObject];
		else
			pf = item;
		[urls addObject:[pf url]];
	}];

	if ([urls count] == 0)
		return;

	BOOL isLocal = [[urls objectAtIndex:0] isFileURL];
	char *pluralS = ([urls count] == 1 ? "" : "s");

	NSAlert *alert = [[NSAlert alloc] init];
	if (isLocal)
		[alert setMessageText:[NSString stringWithFormat:@"Do you want to move the selected file%s to the trash?", pluralS]];
	else
		[alert setMessageText:[NSString stringWithFormat:@"Do you want to permanently delete the selected file%s?", pluralS]];
	[alert addButtonWithTitle:@"OK"];
	[alert addButtonWithTitle:@"Cancel"];
	if (isLocal) {
		[alert setInformativeText:[NSString stringWithFormat:@"%lu file%s will be moved to the trash.", [urls count], pluralS]];
		[alert setAlertStyle:NSWarningAlertStyle];
	} else {
		[alert setInformativeText:[NSString stringWithFormat:@"%lu file%s will be deleted immediately. This operation cannot be undone!", [urls count], pluralS]];
		[alert setAlertStyle:NSCriticalAlertStyle];
	}

	[alert beginSheetModalForWindow:window
			  modalDelegate:self
			 didEndSelector:@selector(removeAlertDidEnd:returnCode:contextInfo:)
			    contextInfo:urls];
}

- (IBAction)rescan:(id)sender
{
	NSInteger row = [explorer selectedRow];

	NSURL *url = [rootButton URL];
	[[ViURLManager defaultManager] flushDirectoryCache];
	[self browseURL:url];

	[explorer selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
		byExtendingSelection:NO];
	[explorer scrollRowToVisible:row];
	explorer.lastSelectedRow = row;
}

- (IBAction)revealInFinder:(id)sender
{
	__block NSMutableArray *urls = [[NSMutableArray alloc] init];
	NSIndexSet *set = [self clickedIndexes];
	[set enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		ProjectFile *pf;
		id item = [explorer itemAtRow:idx];
		if ([item isKindOfClass:[ViCompletion class]])
			pf = [(ViCompletion *)item representedObject];
		else
			pf = item;
		[urls addObject:[pf url]];
	}];
	[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:urls];
}

- (IBAction)openWithFinder:(id)sender
{
	NSIndexSet *set = [self clickedIndexes];
	[set enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		ProjectFile *pf;
		id item = [explorer itemAtRow:idx];
		if ([item isKindOfClass:[ViCompletion class]])
			pf = [(ViCompletion *)item representedObject];
		else
			pf = item;
		[[NSWorkspace sharedWorkspace] openURL:[pf url]];
	}];
}

- (IBAction)newDocument:(id)sender
{
	NSIndexSet *set = [self clickedIndexes];
	NSURL *parent = nil;
	if ([set count] == 1) {
		ProjectFile *pf = [explorer itemAtRow:[set firstIndex]];
		if ([pf isDirectory])
			parent = [pf url];
		else
			parent = [[explorer parentForItem:pf] url];
	}
	if (parent == nil)
		parent = [rootButton URL];

	NSURL *newURL = [parent URLByAppendingPathComponent:@"New File"];
	[[ViURLManager defaultManager] writeDataSafely:[NSData data]
						 toURL:newURL
					  onCompletion:^(NSURL *url, NSDictionary *attrs, NSError *error) {
		if (error)
			[NSApp presentError:error];
		else
			[self rescanURL:parent ifExpanded:NO andSelectURL:url rename:YES];
	}];
}

- (IBAction)newFolder:(id)sender
{
	NSIndexSet *set = [self clickedIndexes];
	NSURL *parent = nil;
	if ([set count] == 1) {
		ProjectFile *pf = [explorer itemAtRow:[set firstIndex]];
		if ([pf isDirectory])
			parent = [pf url];
		else
			parent = [[explorer parentForItem:pf] url];
	}
	if (parent == nil)
		parent = [rootButton URL];

	NSURL *newURL = [parent URLByAppendingPathComponent:@"New Folder"];
	[[ViURLManager defaultManager] createDirectoryAtURL:newURL
					       onCompletion:^(NSError *error) {
		if (error)
			[NSApp presentError:error];
		else
			[self rescanURL:parent ifExpanded:NO andSelectURL:newURL rename:YES];
	}];
}

- (IBAction)bookmarkFolder:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSArray *bookmarks = [defaults arrayForKey:@"bookmarks"];
	NSString *url = [[rootButton URL] absoluteString];
	if (![bookmarks containsObject:url]) {
		if (bookmarks == nil)
			bookmarks = [NSArray arrayWithObject:@"dummy"];
		[defaults setObject:[bookmarks arrayByAddingObject:url] forKey:@"bookmarks"];
	}
}

- (IBAction)gotoBookmark:(id)sender
{
	NSURL *url = [NSURL URLWithString:[sender titleOfSelectedItem]];
	[self browseURL:url];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	__block BOOL fail = NO;

	NSIndexSet *set = [self clickedIndexes];

	if ([menuItem action] == @selector(openInTab:) ||
	    [menuItem action] == @selector(openInCurrentView:) ||
	    [menuItem action] == @selector(openInSplit:) ||
	    [menuItem action] == @selector(openInVerticalSplit:)) {
		/*
		 * Selected files must be files, not directories.
		 */
		[set enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
			ProjectFile *item = [explorer itemAtRow:idx];
			if (item == nil || [self outlineView:explorer isItemExpandable:item]) {
				*stop = YES;
				fail = YES;
			}
		}];
		if (fail)
			return NO;
	}

	/*
	 * Some items only operate on a single entry.
	 */
	if ([set count] > 1 &&
	   ([menuItem action] == @selector(openInCurrentView:) ||
	    [menuItem action] == @selector(renameFile:) ||
	    [menuItem action] == @selector(openInSplit:) ||		/* XXX: Splitting multiple documents is disabled for now, buggy */
	    [menuItem action] == @selector(openInVerticalSplit:)))
		return NO;

	/*
	 * Some items need at least one selected entry.
	 */
	if ([set count] == 0 && [explorer clickedRow] == -1 &&
	   ([menuItem action] == @selector(openInTab:) ||
	    [menuItem action] == @selector(openInCurrentView:) ||
	    [menuItem action] == @selector(openInSplit:) ||
	    [menuItem action] == @selector(openInVerticalSplit:) ||
	    [menuItem action] == @selector(renameFile:) ||
	    [menuItem action] == @selector(removeFiles:) ||
	    [menuItem action] == @selector(revealInFinder:) ||
	    [menuItem action] == @selector(openWithFinder:)))
		return NO;

	/*
	 * Finder operations only implemented for file:// urls.
	 */
	if (![[[explorer itemAtRow:[set firstIndex]] url] isFileURL] &&
	    ([menuItem action] == @selector(revealInFinder:) ||
	     [menuItem action] == @selector(openWithFinder:)))
		return NO;

	return YES;
}

/* FIXME: do this when filter field loses focus */
- (void)resetExplorerView
{
	[filterField setStringValue:@""];
	[self filterFiles:self];
}

- (void)explorerClick:(id)sender
{
	NSIndexSet *set = [explorer selectedRowIndexes];

	if ([set count] == 0) {
		[explorer selectRowIndexes:[NSIndexSet indexSetWithIndex:explorer.lastSelectedRow]
		      byExtendingSelection:NO];
		return;
	}

	if ([set count] > 1)
		return;

	ProjectFile *item = [explorer itemAtRow:[set firstIndex]];
	if (item == nil)
		return;

	if ([self outlineView:explorer isItemExpandable:item])
		return;

	// XXX: open in splits instead if alt key pressed?
	[self openDocuments:sender];
}

- (void)explorerDoubleClick:(id)sender
{
	NSIndexSet *set = [explorer selectedRowIndexes];
	if ([set count] > 1)
		return;
	ProjectFile *item = [explorer itemAtRow:[set firstIndex]];
	if (item && [self outlineView:explorer isItemExpandable:item]) {
		[self browseURL:[item url]];
		[explorer selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
		      byExtendingSelection:NO];
	} else
		[self explorerClick:sender];
}

- (IBAction)searchFiles:(id)sender
{
	[self openExplorerTemporarily:YES];
	[window makeFirstResponder:filterField];
}

- (BOOL)explorerIsOpen
{
	return ![splitView isSubviewCollapsed:explorerView];
}

- (void)openExplorerTemporarily:(BOOL)temporarily
{
	if (![self explorerIsOpen]) {
		if (temporarily)
			closeExplorerAfterUse = YES;
		[splitView setPosition:200.0 ofDividerAtIndex:0];
	}
}

- (void)closeExplorer
{
	[splitView setPosition:0.0 ofDividerAtIndex:0];
}

- (IBAction)toggleExplorer:(id)sender
{
	if ([self explorerIsOpen])
		[self closeExplorer];
	else
		[self openExplorerTemporarily:NO];
}

- (IBAction)focusExplorer:(id)sender
{
	[self openExplorerTemporarily:YES];
	[window makeFirstResponder:explorer];

	[explorer selectRowIndexes:[NSIndexSet indexSetWithIndex:explorer.lastSelectedRow]
	      byExtendingSelection:NO];
	[explorer scrollRowToVisible:explorer.lastSelectedRow];
}

- (void)cancelExplorer
{
	if (closeExplorerAfterUse) {
		[self closeExplorer];
		closeExplorerAfterUse = NO;
	}
	[self resetExplorerView];
	[delegate focusEditor];
}

- (void)expandNextItem:(id)dummy
{
	if (!isFiltering || [itemsToFilter count] == 0)
		return;

	ProjectFile *item = [itemsToFilter objectAtIndex:0];
	[itemsToFilter removeObjectAtIndex:0];
	DEBUG(@"expanding children of next item %@", item);

	[self childrenAtURL:[item url] onCompletion:^(NSMutableArray *children, NSError *error) {
		if (error) {
			/* schedule re-read of parent folder */
			ProjectFile *parent = [explorer parentForItem:item];
			if (parent) {
				DEBUG(@"scheduling re-read of parent item %@", parent);
				[itemsToFilter addObject:parent];
			} else
				DEBUG(@"no parent for item %@", item);
		} else {
			[item setChildren:children];
			[self expandItems:[item children] recursionLimit:3];

			[filteredItems sortUsingComparator:^(id a, id b) {
				ViCompletion *ca = a, *cb = b;
				if (ca.score > cb.score)
					return (NSComparisonResult)NSOrderedAscending;
				else if (cb.score > ca.score)
					return (NSComparisonResult)NSOrderedDescending;
				return (NSComparisonResult)NSOrderedSame;
			}];

			[explorer reloadData];
			if ([itemsToFilter count] > 0)
				[self performSelector:@selector(expandNextItem:) withObject:nil afterDelay:0.0];
		}
	}];
}

- (void)expandItems:(NSArray *)items recursionLimit:(int)recursionLimit
{
	NSString *base = [[rootButton URL] path];
	NSUInteger prefixLength = [base length];
	if (![base hasSuffix:@"/"])
		prefixLength++;

	for (ProjectFile *item in items) {
		DEBUG(@"got item %@", item);
		DEBUG(@"got item url %@", [item url]);
		if ([self outlineView:explorer isItemExpandable:item]) {
			if (recursionLimit > 0 && [item hasCachedChildren])
				[self expandItems:[item children] recursionLimit:recursionLimit - 1];
			else
				/* schedule in runloop */
				[itemsToFilter addObject:item];
		} else {
			ViRegexpMatch *m = nil;
			NSString *p = [[[item url] path] substringFromIndex:prefixLength];
			if (rx == nil || (m = [rx matchInString:p]) != nil) {
				ViCompletion *c = [ViCompletion completionWithContent:p fuzzyMatch:m];
				c.font = font;
				c.representedObject = item;
				c.markColor = [NSColor blackColor];
				[filteredItems addObject:c];
			}
		}
	}
}

- (void)appendFilter:(NSString *)string
           toPattern:(NSMutableString *)pattern
          fuzzyClass:(NSString *)fuzzyClass
{
	NSUInteger i;
	for (i = 0; i < [string length]; i++) {
		unichar c = [string characterAtIndex:i];
		if (i != 0)
			[pattern appendFormat:@"%@*?", fuzzyClass];
		if (c == ' ')
			[pattern appendString:@"([ /])"];
		else
			[pattern appendFormat:@"(%s%C)", [ViRegexp needEscape:c] ? "\\" : "", c];
	}
}

- (IBAction)filterFiles:(id)sender
{
	NSString *filter = [filterField stringValue];

	if ([filter length] == 0) {
		isFiltered = NO;
		isFiltering = NO;
		filteredItems = [NSMutableArray arrayWithArray:rootItems];
		[explorer reloadData];
		[self resetExpandedItems];
		[explorer selectRowIndexes:[NSIndexSet indexSet]
		      byExtendingSelection:NO];
	} else {
		NSMutableString *pattern = [NSMutableString string];
		[pattern appendFormat:@"^.*"];
		[self appendFilter:filter toPattern:pattern fuzzyClass:@"[^/]"];
		[pattern appendString:@"[^/]*$"];

		rx = [[ViRegexp alloc] initWithString:pattern
					      options:ONIG_OPTION_IGNORECASE];

		filteredItems = [NSMutableArray array];
		itemsToFilter = [NSMutableArray array];
		isFiltered = YES;
		isFiltering = YES;

		[self expandItems:rootItems recursionLimit:3];

		[filteredItems sortUsingComparator:^(id a, id b) {
			ViCompletion *ca = a, *cb = b;
			if (ca.score > cb.score)
				return (NSComparisonResult)NSOrderedAscending;
			else if (cb.score > ca.score)
				return (NSComparisonResult)NSOrderedDescending;
			return (NSComparisonResult)NSOrderedSame;
			}];

		[explorer reloadData];
		[explorer selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
		      byExtendingSelection:NO];
		if ([itemsToFilter count] > 0)
			[self expandNextItem:nil];
	}
}

#pragma mark -

- (BOOL)control:(NSControl *)sender
       textView:(NSTextView *)textView
doCommandBySelector:(SEL)aSelector
{
	if ([self isEditing]) {
		if (aSelector == @selector(cancelOperation:)) { // escape
			[explorer abortEditing];
			[window makeFirstResponder:explorer];
			return YES;
		}
		return NO;
	}

	if (aSelector == @selector(insertNewline:)) { // enter
		NSIndexSet *set = [explorer selectedRowIndexes];
		if ([set count] == 0)
			[self cancelExplorer];
		else
			[self explorerClick:sender];
		return YES;
	} else if (aSelector == @selector(moveUp:)) { // up arrow
		NSInteger row = [explorer selectedRow];
		if (row > 0)
			[explorer selectRowIndexes:[NSIndexSet indexSetWithIndex:row - 1]
			      byExtendingSelection:NO];
		return YES;
	} else if (aSelector == @selector(moveDown:)) { // down arrow
		NSInteger row = [explorer selectedRow];
		if (row + 1 < [explorer numberOfRows])
			[explorer selectRowIndexes:[NSIndexSet indexSetWithIndex:row + 1]
			      byExtendingSelection:NO];
		return YES;
	} else if (aSelector == @selector(cancelOperation:)) { // escape
		isFiltering = NO;
		if (isFiltered) {
			[window makeFirstResponder:explorer];
			/* make sure something is selected */
			if ([explorer selectedRow] == -1)
				[explorer selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
				      byExtendingSelection:NO];
		} else
			[self cancelExplorer];
		return YES;
	}

	return NO;
}

#pragma mark -
#pragma mark Explorer Command Parser

- (BOOL)show_menu:(ViCommand *)command
{
	[self actionMenu:explorer];
	return YES;
}

- (BOOL)find:(ViCommand *)command
{
	[window makeFirstResponder:filterField];
	return YES;
}

- (BOOL)cancel_or_reset:(ViCommand *)command
{
	if (isFiltered)
		[self resetExplorerView];
	else
		[self cancelExplorer];
	return YES;
}

- (BOOL)cancel:(ViCommand *)command
{
	[self cancelExplorer];
	return YES;
}

- (BOOL)switch_open:(ViCommand *)command
{
	[self openInCurrentView:nil];
	return YES;
}

- (BOOL)split_open:(ViCommand *)command
{
	[self openInSplit:nil];
	return YES;
}

- (BOOL)vsplit_open:(ViCommand *)command
{
	[self openInVerticalSplit:nil];
	return YES;
}

- (BOOL)tab_open:(ViCommand *)command
{
	[self openInTab:nil];
	return YES;
}

- (BOOL)open:(ViCommand *)command
{
	[self explorerDoubleClick:nil];
	return YES;
}

- (void)resetExpandedItems:(NSArray *)items
{
	for (id item in items) {
		if ([self outlineView:explorer isItemExpandable:item]) {
			ProjectFile *pf = item;
			if ([expandedSet containsObject:pf.url])
				[explorer expandItem:item];
			if ([pf hasCachedChildren])
				[self resetExpandedItems:pf.children];
		}
	}
}

- (void)resetExpandedItems
{
	[self resetExpandedItems:rootItems];
}

- (id)findItemWithURL:(NSURL *)aURL inItems:(NSArray *)items
{
	for (id item in items) {
		if ([[item url] isEqual:aURL])
			return item;
		if ([self outlineView:explorer isItemExpandable:item] && [item hasCachedChildren]) {
			id foundItem = [self findItemWithURL:aURL inItems:[item children]];
			if (foundItem)
				return foundItem;
		}
	}

	return nil;
}

- (void)selectURL:(NSURL *)aURL
{
	id item = [self findItemWithURL:aURL inItems:rootItems];
	if (item) {
		NSInteger row = [explorer rowForItem:item];
		if (row != -1) {
			[explorer selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
			      byExtendingSelection:NO];
			[explorer scrollRowToVisible:row];
			explorer.lastSelectedRow = row;
		}
	}
}

- (void)rescanURL:(NSURL *)aURL
       ifExpanded:(BOOL)ifExpandedFlag
     andSelectURL:(NSURL *)selectedURL
	   rename:(BOOL)renameFlag
{
	if (![aURL isEqual:[rootButton URL]]) {
		id item = [self findItemWithURL:aURL inItems:rootItems];
		if (item == nil)
			return;

		if (ifExpandedFlag && ![explorer isItemExpanded:item])
			return;
	}

	if (selectedURL == nil) {
		id selectedItem = [explorer itemAtRow:[explorer selectedRow]];
		selectedURL = [selectedItem url];
	}

	[[ViURLManager defaultManager] flushCachedContentsOfDirectoryAtURL:aURL];
	[self childrenAtURL:aURL onCompletion:^(NSMutableArray *children, NSError *error) {
		if (error && ![error isFileNotFoundError]) {
			NSAlert *alert = [NSAlert alertWithError:error];
			[alert runModal];
		} else {
			id item = [self findItemWithURL:aURL inItems:rootItems];
			if (item) {
				[item setChildren:children];
			} else {
				rootItems = children;
				[self filterFiles:self];
			}
			[explorer reloadData];
			[self resetExpandedItems];
			[explorer expandItem:[self findItemWithURL:aURL inItems:rootItems]];

			if (renameFlag) {
				item = [self findItemWithURL:selectedURL inItems:rootItems];
				if (item) {
					NSInteger row = [explorer rowForItem:item];
					[self pauseEvents];
					[explorer selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
					[explorer editColumn:0 row:row withEvent:nil select:YES];
				}
			} else {
				[self selectURL:selectedURL];
			}
		}
	}];
}

- (void)rescanURL:(NSURL *)aURL
{
	[self rescanURL:aURL ifExpanded:YES andSelectURL:nil rename:NO];
}

- (BOOL)rescan_files:(ViCommand *)command
{
	ProjectFile *pf = [explorer itemAtRow:[explorer selectedRow]];
	if (![self outlineView:explorer isItemExpandable:pf] || ![explorer isItemExpanded:pf])
		pf = [explorer parentForItem:pf];

	NSURL *parent;
	if (pf)
		parent = [pf url];
	else
		parent = [rootButton URL];

	[self rescanURL:parent];
	return YES;
}

- (BOOL)new_document:(ViCommand *)command
{
	[self newDocument:nil];
	return YES;
}

- (BOOL)new_folder:(ViCommand *)command
{
	[self newFolder:nil];
	return YES;
}

- (BOOL)rename_file:(ViCommand *)command
{
	[self renameFile:nil];
	return YES;
}

- (BOOL)remove_files:(ViCommand *)command
{
	[self removeFiles:nil];
	return YES;
}

- (BOOL)keyManager:(ViKeyManager *)keyManager
   evaluateCommand:(ViCommand *)command
{
	DEBUG(@"command is %@", command);
	id target;
	if ([explorer respondsToSelector:command.action])
		target = explorer;
	else if ([self respondsToSelector:command.action])
		target = self;
	else {
		[windowController message:@"Command not implemented."];
		return NO;
	}

	return (BOOL)[target performSelector:command.action withObject:command];
}

#pragma mark -
#pragma mark Explorer Outline View Delegate

- (void)outlineViewItemWillExpand:(NSNotification *)notification
{
	ProjectFile *pf;
	id item = [[notification userInfo] objectForKey:@"NSObject"];
	if ([item isKindOfClass:[ViCompletion class]])
		pf = [(ViCompletion *)item representedObject];
	else
		pf = item;
	if ([pf hasCachedChildren])
		return;

	[self childrenAtURL:[pf url] onCompletion:^(NSMutableArray *children, NSError *error) {
		if (error)
			[NSApp presentError:error];
		else {
			pf.children = children;
			if (![[pf url] isFileURL]) { /* XXX: did we get here synchronously? */
				[explorer reloadData];
				[explorer expandItem:pf];
			}
		}
	}];
}

- (void)outlineViewItemDidExpand:(NSNotification *)notification
{
	ProjectFile *pf;
	id item = [[notification userInfo] objectForKey:@"NSObject"];
	if ([item isKindOfClass:[ViCompletion class]])
		pf = [(ViCompletion *)item representedObject];
	else
		pf = item;

	[expandedSet addObject:pf.url];
}

- (void)outlineViewItemDidCollapse:(NSNotification *)notification
{
	ProjectFile *pf;
	id item = [[notification userInfo] objectForKey:@"NSObject"];
	if ([item isKindOfClass:[ViCompletion class]])
		pf = [(ViCompletion *)item representedObject];
	else
		pf = item;

	[expandedSet removeObject:pf.url];
}

#pragma mark -
#pragma mark Explorer Outline View Data Source

- (void)outlineView:(NSOutlineView *)outlineView
     setObjectValue:(id)object
     forTableColumn:(NSTableColumn *)tableColumn
	     byItem:(id)item
{
	[self resumeEvents];

	if (![object isKindOfClass:[NSString class]])
		return;

	ProjectFile *file = item;
	NSURL *parentURL = [[file url] URLByDeletingLastPathComponent];
	NSURL *newurl = [[parentURL URLByAppendingPathComponent:object] URLByStandardizingPath];
	if ([[file url] isEqual:newurl])
		return;

	[[ViURLManager defaultManager] moveItemAtURL:[file url]
					       toURL:newurl
					onCompletion:^(NSError *error) {
		if (error)
			[NSApp presentError:error];
		else {
			ViDocument *doc = [windowController documentForURL:[file url]];
			[file setUrl:newurl];
			[doc setFileURL:newurl];
		}
	}];
}

- (id)outlineView:(NSOutlineView *)outlineView
            child:(NSInteger)anIndex
           ofItem:(id)item
{
	if (item == nil)
		return [filteredItems objectAtIndex:anIndex];

	ProjectFile *pf = item;
	if ([item isKindOfClass:[ViCompletion class]])
		pf = [(ViCompletion *)item representedObject];
	if (![pf hasCachedChildren])
		return nil;
	return [[pf children] objectAtIndex:anIndex];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView
   isItemExpandable:(id)item
{
	ProjectFile *pf = item;
	if ([item isKindOfClass:[ViCompletion class]])
		pf = [(ViCompletion *)item representedObject];
	return [pf isDirectory];
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView
  numberOfChildrenOfItem:(id)item
{
	if (item == nil)
		return [filteredItems count];

	ProjectFile *pf = item;
	if ([item isKindOfClass:[ViCompletion class]])
		pf = [(ViCompletion *)item representedObject];
	if (![pf hasCachedChildren])
		return 0;
	return [[pf children] count];
}

- (id)outlineView:(NSOutlineView *)outlineView
objectValueForTableColumn:(NSTableColumn *)tableColumn
           byItem:(id)item
{
	if (isFiltered)
		return [(ViCompletion *)item title];
	else
		return [(ProjectFile *)item name];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView
        isGroupItem:(id)item
{
	return NO;
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView
     heightOfRowByItem:(id)item
{
	return 20;
}

- (NSCell *)outlineView:(NSOutlineView *)outlineView
 dataCellForTableColumn:(NSTableColumn *)tableColumn
                   item:(id)item
{
	NSInteger row = [explorer rowForItem:item];
	NSCell *cell = [tableColumn dataCellForRow:row];

	if (cell) {
		ProjectFile *pf = item;
		if ([item isKindOfClass:[ViCompletion class]])
			pf = [(ViCompletion *)item representedObject];
		NSURL *url = [pf url];
		NSImage *img;
		if ([url isFileURL])
			img = [[NSWorkspace sharedWorkspace] iconForFile:[url path]];
		else {
			if ([self outlineView:outlineView isItemExpandable:item])
				img = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode('fldr')];
			else
				img = [[NSWorkspace sharedWorkspace] iconForFileType:[[url path] pathExtension]];
		}

#if 0
		ViDocument *doc = [[ViDocumentController sharedDocumentController] documentForURL:url];
		if (doc && [doc isDocumentEdited]) {
			INFO(@"doc %@ is edited", doc);
		}
#endif

		[cell setFont:font];
		[img setSize:NSMakeSize(16, 16)];
		[cell setImage:img];
	}

	return cell;
}

@end
