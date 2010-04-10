#import "ProjectDelegate.h"
#import "logging.h"
#import "MHTextIconCell.h"
#import "SFTPConnectionPool.h"
#import "ViWindowController.h" // for goToUrl:

@interface ProjectDelegate (private)
- (NSMutableArray *)childrenAtFileURL:(NSURL *)url rootURL:(NSURL *)rootURL;
- (NSMutableDictionary *)itemAtFileURL:(NSURL *)url rootURL:(NSURL *)rootURL;
- (NSMutableArray *)childrenAtSftpURL:(NSURL *)url connection:(SFTPConnection *)conn;
- (NSMutableDictionary *)itemAtSftpURL:(NSURL *)url connection:(SFTPConnection *)conn;
- (NSMutableDictionary *)itemAtSftpURL:(NSURL *)url connection:(SFTPConnection *)conn attributes:(Attrib *)attributes;
- (NSString *)relativePathForItem:(NSDictionary *)item;
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item;
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item;
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)anIndex ofItem:(id)item;
@end

@implementation ProjectDelegate

@synthesize delegate;

- (id)init
{
	self = [super init];
	if (self)
	{
		rootItems = [[NSMutableArray alloc] init];
		skipRegex = [ViRegexp regularExpressionWithString:[[NSUserDefaults standardUserDefaults] stringForKey:@"skipPattern"]];
	}
	return self;
}

- (void)awakeFromNib
{
	[explorer setTarget:self];
	[explorer setDoubleAction:@selector(explorerDoubleClick:)];
	[explorer setAction:@selector(explorerClick:)];

        [[explorer outlineTableColumn] setDataCell:[[MHTextIconCell alloc] init]];
       
	NSCell *cell = [(NSTableColumn *)[[explorer tableColumns] objectAtIndex:0] dataCell];
	[cell setLineBreakMode:NSLineBreakByTruncatingHead];
	[cell setWraps:NO];

	[[sftpConnectForm cellAtIndex:1] setPlaceholderString:NSUserName()];
}

- (NSMutableArray *)childrenAtFileURL:(NSURL *)url rootURL:(NSURL *)rootURL
{
	NSMutableArray *children = [[NSMutableArray alloc] init];
	NSFileManager *fm = [NSFileManager defaultManager];
	NSError *error = nil;
	NSArray *files = [fm contentsOfDirectoryAtPath:[url path] error:&error];
	if (files == nil) {
		INFO(@"failed to get files: %@", [error localizedDescription]);
		return nil;
	}
	NSString *file;
	for (file in files)
	{
		if (![file hasPrefix:@"."] && [skipRegex matchInString:file] == nil)
		{
			NSURL *childURL = [NSURL fileURLWithPath:[[url path] stringByAppendingPathComponent:file]];
			[children addObject:[self itemAtFileURL:childURL rootURL:rootURL]];
        }
	}
	return children;
}

- (NSMutableArray *)childrenAtSftpURL:(NSURL *)url connection:(SFTPConnection *)conn
{
	NSMutableArray *children = [[NSMutableArray alloc] init];
	NSArray *entries = [conn directoryContentsAtPath:[url path]];
	SFTPDirectoryEntry *entry;
	for (entry in entries)
	{
		NSString *file = [entry filename];
		if (![file hasPrefix:@"."] && [skipRegex matchInString:file] == nil)
		{
			NSURL *newurl = [[NSURL alloc] initWithScheme:[url scheme] host:[conn target] path:[[url path] stringByAppendingPathComponent:file]];
			[children addObject:[self itemAtSftpURL:newurl connection:conn attributes:[entry attributes]]];
		}
	}
	return children;
}

- (NSMutableDictionary *)itemAtFileURL:(NSURL *)url rootURL:(NSURL *)rootURL
{
	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL isDirectory = NO;
	if ([fm fileExistsAtPath:[url path] isDirectory:&isDirectory] && isDirectory)
	{
		NSMutableArray *children = [self childrenAtFileURL:url rootURL:rootURL];
		NSMutableDictionary *root = [NSMutableDictionary dictionaryWithObjectsAndKeys:
			url, @"url",
			children, @"children",
			rootURL, @"root",
			nil];
		return root;
	}
	return [NSMutableDictionary dictionaryWithObjectsAndKeys:url, @"url", rootURL, @"root", nil];
}

- (NSMutableDictionary *)itemAtSftpURL:(NSURL *)url connection:(SFTPConnection *)conn attributes:(Attrib *)attributes
{
	if (attributes && (attributes->flags & SSH2_FILEXFER_ATTR_PERMISSIONS) && S_ISDIR(attributes->perm))
	{
		// It's a directory
		NSMutableArray *children = [self childrenAtSftpURL:url connection:conn];
		NSMutableDictionary *root = [NSMutableDictionary dictionaryWithObjectsAndKeys:
			url, @"url",
			children, @"children",
			nil];
		return root;
	}

	return [NSMutableDictionary dictionaryWithObject:url forKey:@"url"];
}

- (NSMutableDictionary *)itemAtSftpURL:(NSURL *)url connection:(SFTPConnection *)conn
{
	return [self itemAtSftpURL:url connection:conn attributes:[conn stat:[url path]]];
}

- (id)addFileURL:(NSURL *)url
{
        id item = [self itemAtFileURL:url rootURL:url];
	[rootItems addObject:item];
	return item;
}

- (id)addSftpURL:(NSURL *)url
{
	NSString *target = [NSString stringWithFormat:@"%@@%@", [url user] ?: @"", [url host]];
	SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithTarget:target];
	if (conn)
	{
		id item = [self itemAtSftpURL:url connection:conn];
		if (item)
			[rootItems addObject:item];
                return item;
	}
	return nil;
}

- (void)addURL:(NSURL *)aURL
{
	if ([rootItems indexOfObject:aURL] == NSNotFound)
	{
		INFO(@"scheme = %@", [aURL scheme]);
		id item = nil;
		if ([[aURL scheme] isEqualToString:@"file"])
		{
			item = [self addFileURL:aURL];
		}
		else if ([[aURL scheme] isEqualToString:@"sftp"])
		{
			item = [self addSftpURL:aURL];
		}
		else
		{
			INFO(@"unhandled scheme %@", [aURL scheme]);
			return;
		}
		[self filterFiles:self];
		[explorer reloadData];
                [explorer expandItem:item expandChildren:NO];
	}
}

#pragma mark -
#pragma mark Explorer actions

- (IBAction)actionMenu:(id)sender
{
	INFO(@"sender = %@", sender);
	NSEvent *ev = [NSEvent mouseEventWithType:NSLeftMouseDown
	                                 location:NSMakePoint(0, 0)
	                            modifierFlags:0
	                                timestamp:1
	                             windowNumber:[window windowNumber]
	                                  context:[NSGraphicsContext currentContext]
	                              eventNumber:1
	                               clickCount:1
	                                 pressure:0.0];
	[NSMenu popUpContextMenu:actionMenu withEvent:ev forView:sender];
}

- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	INFO(@"return code = %i", returnCode);
	if (returnCode == NSCancelButton)
		return;
	
	for (NSURL *url in [panel URLs])
	{
		[self addURL:url];
	}
}

- (IBAction)addLocation:(id)sender
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setAllowsMultipleSelection:YES];
	[openPanel beginSheetForDirectory:nil
	                             file:nil
	                            types:nil
	                   modalForWindow:window
	                    modalDelegate:self
	                   didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:)
	                      contextInfo:nil];
}

- (void)sftpSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
}

- (IBAction)acceptSftpSheet:(id)sender
{
	if ([[[sftpConnectForm cellAtIndex:0] stringValue] length] == 0)
	{
		NSBeep();
		[sftpConnectForm selectTextAtIndex:0];
		return;
	}
	[NSApp endSheet:sftpConnectView];
	NSString *host = [[sftpConnectForm cellAtIndex:0] stringValue];
	NSString *user = [[sftpConnectForm cellAtIndex:1] stringValue];
	if ([user length] == 0)
		user = [[sftpConnectForm cellAtIndex:1] placeholderString];
	NSString *path = [[sftpConnectForm cellAtIndex:2] stringValue];
	NSString *target = [NSString stringWithFormat:@"%@@%@", user, host];

	SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithTarget:target];
	if (conn)
	{
		INFO(@"connected to %@", target);
		if (![path hasPrefix:@"/"])
		{
			NSString *pwd = [conn currentDirectory];
			if (pwd == nil)
			{
				INFO(@"%s", "FAILED to read current directory");
				return;
			}
			path = [NSString stringWithFormat:@"%@/%@", pwd, path];
		}
		NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"sftp://%@%@", target, path]];
		[self addURL:url];
	}
	else
		INFO(@"FAILED to connect to %@", target);
}

- (IBAction)cancelSftpSheet:(id)sender
{
	[NSApp endSheet:sftpConnectView];
}

- (IBAction)addSFTPLocation:(id)sender
{
	INFO(@"sender = %@, views = %@", sender, sftpConnectView);
	[NSApp beginSheet:sftpConnectView modalForWindow:window modalDelegate:self didEndSelector:@selector(sftpSheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)resetExplorerView
{
        [filterField setStringValue:@""];
        [self filterFiles:self];
        int i, n = [self outlineView:explorer numberOfChildrenOfItem:nil];
        for (i = 0; i < n; i++)
        {
                [explorer expandItem:[self outlineView:explorer child:i ofItem:nil] expandChildren:NO];
        }
}

- (void)explorerClick:(id)sender
{
	NSIndexSet *set = [explorer selectedRowIndexes];
	if ([set count] > 1)
		return;
	NSDictionary *item = [explorer itemAtRow:[set firstIndex]];
	if (item && ![self outlineView:explorer isItemExpandable:item])
		[delegate goToURL:[item objectForKey:@"url"]];

        [self resetExplorerView];
}

- (void)explorerDoubleClick:(id)sender
{
	NSIndexSet *set = [explorer selectedRowIndexes];
	if ([set count] > 1)
		return;
	NSDictionary *item = [explorer itemAtRow:[set firstIndex]];
	if (item && [self outlineView:explorer isItemExpandable:item])
	{
		if ([explorer isItemExpanded:item])
			[explorer collapseItem:item];
		else
			[explorer expandItem:item];
	}
	else
		[self explorerClick:sender];
}

- (IBAction)searchFiles:(id)sender
{
	if ([splitView isSubviewCollapsed:explorerView])
	{
		closeExplorerAfterUse = YES;
		[self toggleExplorer:nil];
	}
	[window makeFirstResponder:filterField];
}

- (void)expandItems:(NSArray *)items intoArray:(NSMutableArray *)expandedArray filter:(ViRegexp *)rx
{
        NSDictionary *item;
        for (item in items)
        {
                if ([self outlineView:explorer isItemExpandable:item])
                {
                        [self expandItems:[item objectForKey:@"children"] intoArray:expandedArray filter:rx];
                }
                else if ([rx matchInString:[[[item objectForKey:@"url"] path] lastPathComponent]])
                {
                        [expandedArray addObject:item];
                }
        }
}

- (IBAction)filterFiles:(id)sender
{
	INFO(@"sender = %@", sender);
	NSString *filter = [filterField stringValue];
	if ([filter length] == 0)
	{
                filteredItems = [[NSMutableArray alloc] initWithArray:rootItems];
	}
	else
	{
                NSMutableString *pattern = [NSMutableString string];
                int i;
                for (i = 0; i < [filter length]; i++)
                {
                        [pattern appendFormat:@".*%C", [filter characterAtIndex:i]];
                }
                [pattern appendString:@".*"];
                //NSString *pattern = [NSString stringWithFormat:@".*%@.*", filter];
                INFO(@"using filter pattern %@", pattern);
                ViRegexp *rx = [ViRegexp regularExpressionWithString:pattern options:ONIG_OPTION_IGNORECASE];
        
                filteredItems = [[NSMutableArray alloc] init];
                [self expandItems:rootItems intoArray:filteredItems filter:rx];
        }
        [explorer reloadData];
}

- (IBAction)toggleExplorer:(id)sender
{
	
}

#pragma mark -

- (BOOL)textField:(NSTextField *)sender doCommandBySelector:(SEL)aSelector
{
	INFO(@"sender = %@, selector = %s", sender, aSelector);
	if (aSelector == @selector(insertNewline:)) // enter
	{
		[self explorerClick:sender];
		return YES;
	}
	else if (aSelector == @selector(moveUp:)) // up arrow
	{
		NSInteger row = [explorer selectedRow];
		if (row > 0)
		{
			[explorer selectRowIndexes:[NSIndexSet indexSetWithIndex:row - 1] byExtendingSelection:NO];
		}
		return YES;
	}
	else if (aSelector == @selector(moveDown:)) // down arrow
	{
		NSInteger row = [explorer selectedRow];
		if (row + 1 < [explorer numberOfRows])
		{
			[explorer selectRowIndexes:[NSIndexSet indexSetWithIndex:row + 1] byExtendingSelection:NO];
		}
		return YES;
	}
	else if (aSelector == @selector(moveRight:)) // right arrow
	{
		NSInteger row = [explorer selectedRow];
		id item = [explorer itemAtRow:row];
		if (item && [self outlineView:explorer isItemExpandable:item])
			[explorer expandItem:item];
		return YES;
	}
	else if (aSelector == @selector(moveLeft:)) // left arrow
	{
		NSInteger row = [explorer selectedRow];
		id item = [explorer itemAtRow:row];
		if (item == nil)
			return YES;
		if ([self outlineView:explorer isItemExpandable:item] && [explorer isItemExpanded:item])
			[explorer collapseItem:item];
		else
		{
			id parent = [explorer parentForItem:item];
			if (parent)
				[explorer selectRowIndexes:[NSIndexSet indexSetWithIndex:[explorer rowForItem:parent]] byExtendingSelection:NO];
		}
		return YES;
	}
	else if (aSelector == @selector(cancelOperation:)) // escape
	{
		if (closeExplorerAfterUse)
		{
			[self toggleExplorer:self];
			closeExplorerAfterUse = NO;
		}
		[self resetExplorerView];
		[delegate focusEditor];
		return YES;
	}

	return NO;
}

#pragma mark -
#pragma mark Explorer Outline View Data Source

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)anIndex ofItem:(id)item
{
	if (item == nil)
		return [filteredItems objectAtIndex:anIndex];
	return [[item objectForKey:@"children"] objectAtIndex:anIndex];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return [item objectForKey:@"children"] != nil;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if (item == nil)
		return [filteredItems count];

	return [[item objectForKey:@"children"] count];
}

- (NSString *)relativePathForItem:(NSDictionary *)item
{
        NSString *root = [[item objectForKey:@"root"] path];
        NSString *path = [[item objectForKey:@"url"] path];
        if ([path length] > [root length])
                return [path substringWithRange:NSMakeRange([root length] + 1, [path length] - [root length] - 1)];
        return path;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if ([[filterField stringValue] length] > 0)
        {
                return [self relativePathForItem:item];
        }
        else
                return [[[item objectForKey:@"url"] path] lastPathComponent];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
	return NO;
	// return [filteredItems indexOfObject:item] != NSNotFound;
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
	if ([self outlineView:outlineView isGroupItem:item])
		return 20;
	return 16;
}

- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	NSCell *cell = [tableColumn dataCellForRow:[explorer rowForItem:item]];
	if (cell)
	{
		NSURL *url = [item objectForKey:@"url"];
		NSImage *img;
		if ([url isFileURL])
			img = [[NSWorkspace sharedWorkspace] iconForFile:[url path]];
		else
		{
			if ([self outlineView:outlineView isItemExpandable:item])
				img = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode('fldr')];
			else
				img = [[NSWorkspace sharedWorkspace] iconForFileType:[[url path] pathExtension]];
		}
		if (![self outlineView:outlineView isGroupItem:item])
		{
			[img setSize:NSMakeSize(16, 16)];
			[cell setFont:[NSFont systemFontOfSize:11.0]];
		}
		else
		{
			[img setSize:NSMakeSize(16, 16)];
			[cell setFont:[NSFont systemFontOfSize:13.0]];
		}
		[cell setImage:img];
	}
	return cell;
}

@end
