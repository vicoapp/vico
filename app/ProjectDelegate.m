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
#import "NSObject+SPInvocationGrabbing.h"
#import "ViCommon.h"
#import "NSURL-additions.h"

@interface ProjectDelegate (private)
- (void)recursivelySortProjectFiles:(NSMutableArray *)children;
- (NSString *)relativePathForItem:(NSDictionary *)item;
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item;
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item;
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)anIndex ofItem:(id)item;
- (void)expandNextItem;
- (void)expandItems:(NSArray *)items recursionLimit:(int)recursionLimit;
- (void)sortProjectFiles:(NSMutableArray *)children;
- (BOOL)rescan_files:(ViCommand *)command;
- (NSMutableArray *)filteredContents:(NSArray *)contents ofDirectory:(NSURL *)url;
- (void)resetExpandedItems;
- (id)findItemWithURL:(NSURL *)aURL inItems:(NSArray *)items;
- (id)findItemWithURL:(NSURL *)aURL;
- (NSInteger)rowForItemWithURL:(NSURL *)aURL;
- (BOOL)selectItemAtRow:(NSInteger)row;
- (BOOL)selectItem:(id)item;
- (BOOL)selectItemWithURL:(NSURL *)aURL;
- (void)rescanURL:(NSURL *)aURL
     onlyIfCached:(BOOL)cacheFlag
     andRenameURL:(NSURL *)renameURL;
- (void)rescanURL:(NSURL *)aURL;
- (void)resetExplorerView;
@end

@implementation ProjectFile

@synthesize score, url, children, isDirectory;

- (id)initWithURL:(NSURL *)aURL attributes:(NSDictionary *)aDictionary
{
	self = [super init];
	if (self) {
		attributes = aDictionary;
		isDirectory = [[attributes fileType] isEqualToString:NSFileTypeDirectory];
		[self setURL:aURL];
	}
	return self;
}

+ (id)fileWithURL:(NSURL *)aURL attributes:(NSDictionary *)aDictionary
{
	return [[ProjectFile alloc] initWithURL:aURL attributes:aDictionary];
}

- (BOOL)hasCachedChildren
{
	return children != nil;
}

- (void)setURL:(NSURL *)aURL
{
	url = aURL;
	nameIsDirty = YES;
	iconIsDirty = YES;
}

- (NSString *)name
{
	if (nameIsDirty) {
		if ([url isFileURL])
			name = [[NSFileManager defaultManager] displayNameAtPath:[url path]];
		else
			name = [url lastPathComponent];
		nameIsDirty = NO;
	}
	return name;
}

- (NSImage *)icon
{
	if (iconIsDirty) {
		if ([url isFileURL])
			icon = [[NSWorkspace sharedWorkspace] iconForFile:[url path]];
		else if (isDirectory)
			icon = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode('fldr')];
		else
			icon = [[NSWorkspace sharedWorkspace] iconForFileType:[url pathExtension]];
		[icon setSize:NSMakeSize(16, 16)];
		iconIsDirty = NO;
	}
	return icon;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ProjectFile: %@>", url];
}

@end

@implementation ProjectDelegate

@synthesize delegate;
@synthesize outlineView = explorer;

- (id)init
{
	self = [super init];
	if (self) {
		history = [[ViJumpList alloc] init];
		[history setDelegate:self];
		font = [NSFont systemFontOfSize:11.0];
		expandedSet = [NSMutableSet set];
		width = 200.0;
	}
	return self;
}

- (void)compileSkipPattern
{
	NSError *error = nil;
	skipRegex = [[ViRegexp alloc] initWithString:[[NSUserDefaults standardUserDefaults] stringForKey:@"skipPattern"] options:0 error:&error];
	if (error) {
		[windowController message:@"Invalid regular expression in skipPattern: %@", [error localizedDescription]];
		skipRegex = nil;
	}
}

- (void)awakeFromNib
{
	explorer.keyManager = [[ViKeyManager alloc] initWithTarget:self
							defaultMap:[ViMap explorerMap]];
	[explorer setTarget:self];
	[explorer setDoubleAction:@selector(explorerDoubleClick:)];
	[explorer setAction:@selector(explorerClick:)];
	[[sftpConnectForm cellAtIndex:1] setPlaceholderString:NSUserName()];
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

	[self compileSkipPattern];
	[[NSUserDefaults standardUserDefaults] addObserver:self
						forKeyPath:@"skipPattern"
						   options:NSKeyValueObservingOptionNew
						   context:NULL];

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(URLContentsWasCached:)
						     name:ViURLContentsCachedNotification
						   object:[ViURLManager defaultManager]];

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(firstResponderChanged:)
						     name:ViFirstResponderChangedNotification
						   object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(documentEditedChanged:)
						     name:ViDocumentEditedChangedNotification
						   object:nil];

	[self browseURL:windowController.baseURL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
		      ofObject:(id)object
			change:(NSDictionary *)change
		       context:(void *)context
{
	if ([keyPath isEqualToString:@"skipPattern"]) {
		[self compileSkipPattern];
		rootItems = nil;
		[explorer reloadData];
		[self browseURL:rootURL];
		return;
	}

	/* only explorecaseignore, exploresortfolders and skipPattern options observed */
	/* re-sort explorer */
	if (rootItems) {
		[self recursivelySortProjectFiles:rootItems];
		if (!isFiltered)
			[self filterFiles:self];
	}
}

- (ProjectFile *)fileForItem:(id)item
{
	if ([item isKindOfClass:[ViCompletion class]])
		return [(ViCompletion *)item representedObject];
	return item;
}

- (NSMutableArray *)filteredContents:(NSArray *)files ofDirectory:(NSURL *)url
{
	if (files == nil)
		return nil;

	id olditem = [self findItemWithURL:url];

	NSMutableArray *children = [NSMutableArray array];
	for (NSArray *entry in files) {
		NSString *filename = [entry objectAtIndex:0];
		NSDictionary *attributes = [entry objectAtIndex:1];
		if ([skipRegex matchInString:filename] == nil) {
			NSURL *curl = [url URLByAppendingPathComponent:filename];
			if ([curl isFileURL] && [[attributes fileType] isEqualToString:NSFileTypeSymbolicLink]) {
				/*
				 * XXX: resolve symlinks for all URL types!
				 */
				NSURL *symurl = [curl URLByResolvingSymlinksInPath];
				attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[symurl path] error:nil];
			}
			ProjectFile *pf = [ProjectFile fileWithURL:curl attributes:attributes];
			if ([pf isDirectory]) {
				ProjectFile *oldPf = nil;
				if (olditem)
					oldPf = [self findItemWithURL:curl inItems:[olditem children]];
				if (oldPf && [oldPf hasCachedChildren])
					pf.children = oldPf.children;
				else {
					NSArray *contents = [[ViURLManager defaultManager] cachedContentsOfDirectoryAtURL:pf.url];
					pf.children = [self filteredContents:contents ofDirectory:pf.url];
				}
			}
			[children addObject:pf];
		}
	}

	[self sortProjectFiles:children];

	return children;
}

- (void)childrenAtURL:(NSURL *)url onCompletion:(void (^)(NSMutableArray *, NSError *))aBlock
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

- (BOOL)isEditing
{
	return [explorer editedRow] != -1;
}

- (void)browseURL:(NSURL *)aURL andDisplay:(BOOL)display jump:(BOOL)jump
{
	[self childrenAtURL:aURL onCompletion:^(NSMutableArray *children, NSError *error) {
		if (error) {
			NSAlert *alert = [NSAlert alertWithError:error];
			[alert runModal];
		} else {
			if (jump)
				[history pushURL:rootURL line:0 column:0 view:nil];
			if (display)
				[self openExplorerTemporarily:NO];
			rootItems = children;
			[self filterFiles:self];
			[explorer reloadData];
			[self resetExpandedItems];
			rootURL = aURL;
			[windowController setBaseURL:aURL];

			if (!jump || ([[explorer selectedRowIndexes] count] == 0 && [window firstResponder] == explorer))
				[self selectItemAtRow:0];
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
	NSUInteger zero = 0;
	NSView *view = nil;
	return [history backwardToURL:&rootURL line:&zero column:&zero view:&view];
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
		id item = [explorer itemAtRow:idx];
		ProjectFile *pf = [self fileForItem:item];
		if (pf && ![self outlineView:explorer isItemExpandable:item]) {
			[delegate gotoURL:pf.url];
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
		id item = [explorer itemAtRow:idx];
		ProjectFile *pf = [self fileForItem:item];
		if (pf && ![self outlineView:explorer isItemExpandable:item]) {
			NSError *err = nil;
			ViDocument *doc = [[ViDocumentController sharedDocumentController] openDocumentWithContentsOfURL:pf.url
														 display:NO
														   error:&err];
			if (err)
				[windowController message:@"%@: %@", pf.url, [err localizedDescription]];
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
	ProjectFile *pf = [self fileForItem:item];
	if (!pf)
		return;
	NSError *err = nil;
	ViDocument *doc = [[ViDocumentController sharedDocumentController] openDocumentWithContentsOfURL:pf.url
												 display:NO
												   error:&err];

	if (err)
		[windowController message:@"%@: %@", pf.url, [err localizedDescription]];
	else if (doc)
		[windowController switchToDocument:doc];
	[self cancelExplorer];
}

- (IBAction)openInSplit:(id)sender
{
	__block BOOL didOpen = NO;
	NSIndexSet *set = [self clickedIndexes];
	[set enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		id item = [explorer itemAtRow:idx];
		ProjectFile *pf = [self fileForItem:item];
		if (pf && ![self outlineView:explorer isItemExpandable:item]) {
			[windowController splitVertically:NO
						  andOpen:pf.url
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
		id item = [explorer itemAtRow:idx];
		ProjectFile *pf = [self fileForItem:item];
		if (pf && ![self outlineView:explorer isItemExpandable:item]) {
			[windowController splitVertically:YES
						  andOpen:pf.url
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
	id item = [explorer itemAtRow:row];
	if (item == nil)
		return;
	if (isFiltered) {
		[self resetExplorerView];
		item = [item representedObject];
	}
	row = [explorer rowForItem:item];
	if (row != -1) {
		[self selectItemAtRow:row];
		[explorer editColumn:0 row:row withEvent:nil select:YES];
	}
}

- (void)removeAlertDidEnd:(NSAlert *)alert
               returnCode:(NSInteger)returnCode
              contextInfo:(void *)contextInfo
{
	if (returnCode != NSAlertFirstButtonReturn)
		return;

	NSMutableArray *urls = [[NSMutableArray alloc] init];
	NSIndexSet *set = [self clickedIndexes];
	[set enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		id item = [explorer itemAtRow:idx];
		ProjectFile *pf = [self fileForItem:item];
		[urls addObject:pf.url];
	}];

	[[ViURLManager defaultManager] removeItemsAtURLs:urls onCompletion:^(NSError *error) {
		if (error != nil)
			[NSApp presentError:error];

		NSMutableSet *set = [NSMutableSet set];
		for (NSURL *url in urls) {
			id item = [self findItemWithURL:url];
			id parent = [explorer parentForItem:item];
			if (parent == nil)
				[set addObject:rootURL];
			else
				[set addObject:[parent url]];
		}

		for (NSURL *url in set)
			[[ViURLManager defaultManager] notifyChangedDirectoryAtURL:url];

		if (isFiltered)
			[self resetExplorerView];
	}];
}

- (IBAction)removeFiles:(id)sender
{
	NSInteger nselected = [[self clickedIndexes] count];
	if (nselected == 0)
		return;

	BOOL isLocal = [rootURL isFileURL];
	char *pluralS = (nselected == 1 ? "" : "s");

	NSAlert *alert = [[NSAlert alloc] init];
	if (isLocal)
		[alert setMessageText:[NSString stringWithFormat:@"Do you want to move the selected file%s to the trash?", pluralS]];
	else
		[alert setMessageText:[NSString stringWithFormat:@"Do you want to permanently delete the selected file%s?", pluralS]];
	[alert addButtonWithTitle:@"OK"];
	[alert addButtonWithTitle:@"Cancel"];
	if (isLocal) {
		[alert setInformativeText:[NSString stringWithFormat:@"%lu file%s will be moved to the trash.", nselected, pluralS]];
		[alert setAlertStyle:NSWarningAlertStyle];
	} else {
		[alert setInformativeText:[NSString stringWithFormat:@"%lu file%s will be deleted immediately. This operation cannot be undone!", nselected, pluralS]];
		[alert setAlertStyle:NSCriticalAlertStyle];
	}

	[alert beginSheetModalForWindow:window
			  modalDelegate:self
			 didEndSelector:@selector(removeAlertDidEnd:returnCode:contextInfo:)
			    contextInfo:nil];
}

- (IBAction)rescan:(id)sender
{
	ProjectFile *pf = [explorer itemAtRow:[explorer selectedRow]];
	if (![self outlineView:explorer isItemExpandable:pf] || ![explorer isItemExpanded:pf])
		pf = [explorer parentForItem:pf];

	NSURL *parent;
	if (pf)
		parent = [pf url];
	else
		parent = rootURL;

	[self rescanURL:parent];

#if 0
	NSInteger row = [explorer selectedRow];

	NSURL *url = rootURL;
	[[ViURLManager defaultManager] flushDirectoryCache];
	[self browseURL:url];

	[explorer selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
		byExtendingSelection:NO];
	[explorer scrollRowToVisible:row];
	explorer.lastSelectedRow = row;
#endif
}

- (IBAction)revealInFinder:(id)sender
{
	NSMutableArray *urls = [[NSMutableArray alloc] init];
	NSIndexSet *set = [self clickedIndexes];
	[set enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		id item = [explorer itemAtRow:idx];
		ProjectFile *pf = [self fileForItem:item];
		[urls addObject:pf.url];
	}];
	[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:urls];
}

- (IBAction)openWithFinder:(id)sender
{
	NSIndexSet *set = [self clickedIndexes];
	[set enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		id item = [explorer itemAtRow:idx];
		ProjectFile *pf = [self fileForItem:item];
		[[NSWorkspace sharedWorkspace] openURL:pf.url];
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
		parent = rootURL;

	NSURL *newURL = [parent URLByAppendingPathComponent:@"New File"];
	[[ViURLManager defaultManager] writeDataSafely:[NSData data]
						 toURL:newURL
					  onCompletion:^(NSURL *url, NSDictionary *attrs, NSError *error) {
		if (error)
			[NSApp presentError:error];
		else
			[self rescanURL:parent onlyIfCached:NO andRenameURL:url];
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
		parent = rootURL;

	NSURL *newURL = [parent URLByAppendingPathComponent:@"New Folder"];
	[[ViURLManager defaultManager] createDirectoryAtURL:newURL
					       onCompletion:^(NSError *error) {
		if (error)
			[NSApp presentError:error];
		else
			[self rescanURL:parent onlyIfCached:NO andRenameURL:newURL];
	}];
}

- (IBAction)bookmarkFolder:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSArray *bookmarks = [defaults arrayForKey:@"bookmarks"];
	NSString *url = [rootURL absoluteString];
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
			id item = [explorer itemAtRow:idx];
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
	 ProjectFile *pf = [self fileForItem:[explorer itemAtRow:[set firstIndex]]];
	if (![pf.url isFileURL] &&
	    ([menuItem action] == @selector(revealInFinder:) ||
	     [menuItem action] == @selector(openWithFinder:)))
		return NO;

	/*
	 * Some operations not applicable in filtered list.
	 */
	if (isFiltered &&
	    ([menuItem action] == @selector(rescan:) ||
	     [menuItem action] == @selector(addSFTPLocation:) ||
	     [menuItem action] == @selector(newFolder:) ||
	     [menuItem action] == @selector(newDocument:)))
		return NO;

	return YES;
}

- (void)resetExplorerView
{
	[filterField setStringValue:@""];
	[self filterFiles:self];
}

- (void)explorerClick:(id)sender
{
	NSIndexSet *set = [explorer selectedRowIndexes];

	if ([set count] == 0) {
		[self selectItemAtRow:explorer.lastSelectedRow];
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
		[self selectItemAtRow:0];
	} else
		[self explorerClick:sender];
}

- (IBAction)searchFiles:(id)sender
{
	NSToolbar *toolbar = [window toolbar];
	if (![[toolbar items] containsObject:searchToolbarItem]) {
		NSBeep();
		return;
	}
	hideToolbarAfterUse = ![toolbar isVisible];
	[toolbar setVisible:YES];
	if (![[toolbar visibleItems] containsObject:searchToolbarItem]) {
		if (hideToolbarAfterUse) {
			[toolbar setVisible:NO];
			hideToolbarAfterUse = NO;
		}
		NSBeep();
		return;
	}
	[window makeFirstResponder:filterField];
}

- (void)firstResponderChanged:(NSNotification *)notification
{
	NSView *view = [notification object];
	if (view == filterField)
		[self openExplorerTemporarily:YES];
	else if ([view isKindOfClass:[NSView class]] && ![view isDescendantOf:explorerView]) {
		if ([view isKindOfClass:[NSTextView class]] && [(NSTextView *)view isFieldEditor])
			return;
		if (closeExplorerAfterUse) {
			[self closeExplorer];
			closeExplorerAfterUse = NO;
		}
		if (hideToolbarAfterUse) {
			NSToolbar *toolbar = [window toolbar];
			[toolbar setVisible:NO];
			hideToolbarAfterUse = NO;
		}
	}
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
		[splitView setPosition:width ofDividerAtIndex:0];
	}
}

- (void)closeExplorer
{
	width = [[[splitView subviews] objectAtIndex:0] bounds].size.width;
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

	[self selectItemAtRow:explorer.lastSelectedRow];
	[explorer scrollRowToVisible:explorer.lastSelectedRow];
}

- (void)cancelExplorer
{
	[delegate focusEditorDelayed:nil];
	if (closeExplorerAfterUse) {
		[self closeExplorer];
		closeExplorerAfterUse = NO;
	}
	if (hideToolbarAfterUse) {
		NSToolbar *toolbar = [window toolbar];
		[toolbar setVisible:NO];
		hideToolbarAfterUse = NO;
	}
	[self resetExplorerView];
}

- (void)expandItems:(NSArray *)items
{
	[self expandItems:items recursionLimit:3];

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
		[[self nextRunloop] expandNextItem];
}

- (void)expandNextItem
{
	if (!isFiltering || [itemsToFilter count] == 0)
		return;

	ProjectFile *item = [itemsToFilter objectAtIndex:0];
	[itemsToFilter removeObjectAtIndex:0];

	if ([item hasCachedChildren]) {
		[self expandItems:[item children]];
		return;
	}

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
			DEBUG(@"expanding children of item %@", item);
			[self expandItems:[item children]];
		}
	}];
}

- (void)expandItems:(NSArray *)items recursionLimit:(int)recursionLimit
{
	NSString *base = [rootURL path];
	NSUInteger prefixLength = [base length];
	if (![base hasSuffix:@"/"])
		prefixLength++;

	for (ProjectFile *item in items) {
		DEBUG(@"got item %@", item);
		DEBUG(@"got item url %@", [item url]);
		if ([self outlineView:explorer isItemExpandable:item]) {
			if (recursionLimit > 0 && [item hasCachedChildren]) {
				DEBUG(@"expanding children of item %@", item);
				[self expandItems:[item children] recursionLimit:recursionLimit - 1];
			} else
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
			[pattern appendString:@"(\\W*?)"];
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

		[self expandItems:rootItems];
		[self selectItemAtRow:0];
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
			[self selectItemAtRow:row - 1];
		return YES;
	} else if (aSelector == @selector(moveDown:)) { // down arrow
		NSInteger row = [explorer selectedRow];
		if (row + 1 < [explorer numberOfRows])
			[self selectItemAtRow:row + 1];
		return YES;
	} else if (aSelector == @selector(cancelOperation:)) { // escape
		isFiltering = NO;
		if (isFiltered) {
			[window makeFirstResponder:explorer];
			/* make sure something is selected */
			if ([explorer selectedRow] == -1)
				[self selectItemAtRow:0];
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
		if ([[item url] isEqualToURL:aURL])
			return item;
		if ([self outlineView:explorer isItemExpandable:item] && [item hasCachedChildren]) {
			id foundItem = [self findItemWithURL:aURL inItems:[item children]];
			if (foundItem)
				return foundItem;
		}
	}

	return nil;
}

- (id)findItemWithURL:(NSURL *)aURL
{
	return [self findItemWithURL:aURL inItems:rootItems];
}

- (NSInteger)rowForItemWithURL:(NSURL *)aURL
{
	id item = [self findItemWithURL:aURL];
	if (item == nil)
		return -1;
	NSURL *parentURL = [[[self fileForItem:item] url] URLByDeletingLastPathComponent];
	if (parentURL && ![parentURL isEqualToURL:rootURL]) {
		NSInteger parentRow = [self rowForItemWithURL:parentURL];
		if (parentRow != -1)
			[explorer expandItem:[explorer itemAtRow:parentRow]];
	}
	return [explorer rowForItem:item];
}

- (BOOL)selectItemAtRow:(NSInteger)row
{
	if (row == -1)
		return NO;
	[explorer selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
	      byExtendingSelection:NO];
	[explorer scrollRowToVisible:row];
	explorer.lastSelectedRow = row;

	return YES;
}

- (BOOL)selectItem:(id)item
{
	NSInteger row = [explorer rowForItem:item];
	if (row == -1)
		return NO;
	[explorer selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
	      byExtendingSelection:NO];
	return YES;
}

- (BOOL)selectItemWithURL:(NSURL *)aURL
{
	return [self selectItemAtRow:[self rowForItemWithURL:aURL]];
}

- (BOOL)displaysURL:(NSURL *)aURL
{
	return [rootURL isEqualToURL:aURL] ||
	       [self findItemWithURL:aURL] != nil;
}

- (void)URLContentsWasCached:(NSNotification *)notification
{
	NSURL *url = [[notification userInfo] objectForKey:@"URL"];

	if (isFiltering || isExpandingTree || [self isEditing]) {
		DEBUG(@"ignoring changes to directory %@", url);
		return;
	}

	ViURLManager *urlman = [ViURLManager defaultManager];
	NSArray *contents = [urlman cachedContentsOfDirectoryAtURL:url];
	if (contents == nil) {
		DEBUG(@"huh? cached contents of %@ gone already!?", url);
		return;
	}

	if (rootURL && ![url hasPrefix:rootURL]) {
		DEBUG(@"changed URL %@ currently not shown in this explorer, ignoring", url);
		return;
	}

	DEBUG(@"updating contents of %@", url);
	NSMutableArray *children = [self filteredContents:contents ofDirectory:url];

	id item = [self findItemWithURL:url];
	if (item) {
		[item setChildren:children];
	} else if ([url isEqualToURL:rootURL]) {
		rootItems = children;
		[self filterFiles:self];
	} else {
		DEBUG(@"URL %@ not displayed in this explorer (root is %@)", url, rootURL);
		return;
	}

	if (!isFiltered) {
		[explorer reloadData];
		[self resetExpandedItems];
	}
}

- (void)rescanURL:(NSURL *)aURL
     onlyIfCached:(BOOL)cacheFlag
     andRenameURL:(NSURL *)renameURL
{
	ViURLManager *urlman = [ViURLManager defaultManager];

	if (cacheFlag) {
		if (![urlman directoryIsCachedAtURL:aURL]) {
			DEBUG(@"changed URL %@ is not cached", aURL);
			return;
		}
		if (![aURL hasPrefix:rootURL]) {
			DEBUG(@"changed URL %@ currently not shown in explorer, flushing cache", aURL);
			[urlman flushCachedContentsOfDirectoryAtURL:aURL];
			return;
		}
	}

	NSURL *selectedURL = renameURL;
	if (selectedURL == nil) {
		id selectedItem = [explorer itemAtRow:[explorer selectedRow]];
		selectedURL = [selectedItem url];
	}

	[urlman flushCachedContentsOfDirectoryAtURL:aURL];
	[self childrenAtURL:aURL onCompletion:^(NSMutableArray *children, NSError *error) {
		if (error && ![error isFileNotFoundError]) {
			NSAlert *alert = [NSAlert alertWithError:error];
			[alert runModal];
		} else {
			/* The notification should already have reloaded the data. */
			[explorer expandItem:[self findItemWithURL:aURL]];

			if (renameURL) {
				id item = [self findItemWithURL:renameURL];
				if (item) {
					NSInteger row = [explorer rowForItem:item];
					[self selectItemAtRow:row];
					[explorer editColumn:0 row:row withEvent:nil select:YES];
				}
			} else {
				[self selectItemWithURL:selectedURL];
			}
		}
	}];
}

- (void)rescanURL:(NSURL *)aURL
{
	[self rescanURL:aURL onlyIfCached:YES andRenameURL:nil];
}

- (BOOL)rescan_files:(ViCommand *)command
{
	[self rescan:nil];
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
	id item = [[notification userInfo] objectForKey:@"NSObject"];
	ProjectFile *pf = [self fileForItem:item];
	if ([pf hasCachedChildren])
		return;

	__block BOOL directoryContentsIsAsync = NO;
	isExpandingTree = YES;
	[self childrenAtURL:pf.url onCompletion:^(NSMutableArray *children, NSError *error) {
		if (error)
			[NSApp presentError:error];
		else {
			pf.children = children;
			if (directoryContentsIsAsync) {
				[explorer reloadData];
				[explorer expandItem:pf];
			}
		}
	}];
	isExpandingTree = NO;
	directoryContentsIsAsync = YES;
}

- (void)outlineViewItemDidExpand:(NSNotification *)notification
{
	id item = [[notification userInfo] objectForKey:@"NSObject"];
	ProjectFile *pf = [self fileForItem:item];
	[expandedSet addObject:pf.url];
}

- (void)outlineViewItemDidCollapse:(NSNotification *)notification
{
	id item = [[notification userInfo] objectForKey:@"NSObject"];
	ProjectFile *pf = [self fileForItem:item];
	[expandedSet removeObject:pf.url];
}

#pragma mark -
#pragma mark Explorer Outline View Data Source

- (void)outlineView:(NSOutlineView *)outlineView
     setObjectValue:(id)object
     forTableColumn:(NSTableColumn *)tableColumn
	     byItem:(id)item
{
	if (![object isKindOfClass:[NSString class]])
		return;

	ProjectFile *file = item;
	NSURL *parentURL = [[file url] URLByDeletingLastPathComponent];
	NSURL *newurl = [[parentURL URLByAppendingPathComponent:object] URLByStandardizingPath];
	if ([[file url] isEqualToURL:newurl])
		return;

	[[ViURLManager defaultManager] moveItemAtURL:[file url]
					       toURL:newurl
					onCompletion:^(NSError *error) {
		if (error) {
			[NSApp presentError:error];
			if ([error isFileNotFoundError])
				[[ViURLManager defaultManager] notifyChangedDirectoryAtURL:parentURL];
		} else {
			ViDocument *doc = [windowController documentForURL:[file url]];
			[file setURL:newurl];
			[doc setFileURL:newurl];
			[explorer reloadData];
			[[ViURLManager defaultManager] notifyChangedDirectoryAtURL:parentURL];
		}
	}];
}

- (id)outlineView:(NSOutlineView *)outlineView
            child:(NSInteger)anIndex
           ofItem:(id)item
{
	if (item == nil)
		return [filteredItems objectAtIndex:anIndex];

	ProjectFile *pf = [self fileForItem:item];
	if (![pf hasCachedChildren])
		return nil;
	return [pf.children objectAtIndex:anIndex];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView
   isItemExpandable:(id)item
{
	ProjectFile *pf = [self fileForItem:item];
	return [pf isDirectory];
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView
  numberOfChildrenOfItem:(id)item
{
	if (item == nil)
		return [filteredItems count];

	ProjectFile *pf = [self fileForItem:item];
	if (![pf hasCachedChildren])
		return 0;
	return [pf.children count];
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
	NSDocumentController *docController = [NSDocumentController sharedDocumentController];
	NSInteger row = [explorer rowForItem:item];
	NSCell *cell = [tableColumn dataCellForRow:row];
	if (cell) {
		ProjectFile *pf = [self fileForItem:item];
		ViDocument *doc = [docController documentForURL:pf.url];
		if ([doc isDocumentEdited])
			[(MHTextIconCell *)cell setModified:YES];
		else
			[(MHTextIconCell *)cell setModified:NO];
		[cell setFont:font];
		[cell setImage:[pf icon]];
	}

	return cell;
}

- (void)documentEditedChanged:(NSNotification *)notification
{
	ViDocument *doc = [notification object];
	id item = [self findItemWithURL:[doc fileURL]];
	if (item) {
		NSInteger row = [explorer rowForItem:item];
		if (row != -1)
			[explorer reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row]
					    columnIndexes:[NSIndexSet indexSetWithIndex:0]];
	}
}

@end
