#import "ProjectDelegate.h"
#import "logging.h"
#import "MHTextIconCell.h"
#import "SFTPConnectionPool.h"
#import "ViWindowController.h" // for goToUrl:

@interface ProjectDelegate (private)
- (NSMutableArray *)childrenAtFileURL:(NSURL *)url rootURL:(NSURL *)rootURL;
- (NSMutableDictionary *)itemAtFileURL:(NSURL *)url rootURL:(NSURL *)rootURL;
- (NSMutableArray *)childrenAtSftpURL:(NSURL *)url connection:(SFTPConnection *)conn rootURL:(NSURL *)rootURL error:(NSError **)outError;
- (NSMutableDictionary *)itemAtSftpURL:(NSURL *)url connection:(SFTPConnection *)conn rootURL:(NSURL *)rootURL error:(NSError **)outError;
- (NSMutableDictionary *)itemAtSftpURL:(NSURL *)url connection:(SFTPConnection *)conn rootURL:(NSURL *)rootURL attributes:(Attrib *)attributes error:(NSError **)outError;
- (NSString *)relativePathForItem:(NSDictionary *)item;
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item;
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item;
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)anIndex ofItem:(id)item;
- (void)cancelExplorer;
@end

@implementation ProjectDelegate

@synthesize delegate;

- (id)init
{
	self = [super init];
	if (self) {
		rootItems = [[NSMutableArray alloc] init];
		skipRegex = [ViRegexp regularExpressionWithString:[[NSUserDefaults standardUserDefaults] stringForKey:@"skipPattern"]];

		matchParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		[matchParagraphStyle setLineBreakMode:NSLineBreakByTruncatingHead];
	}
	return self;
}

- (void)awakeFromNib
{
	[explorer setTarget:self];
	[explorer setDoubleAction:@selector(explorerDoubleClick:)];
	[explorer setAction:@selector(explorerClick:)];

        [[explorer outlineTableColumn] setDataCell:[[MHTextIconCell alloc] init]];
	[self hideExplorerSearch];
       
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
	for (file in files) {
		if (![file hasPrefix:@"."] && [skipRegex matchInString:file] == nil) {
			NSURL *childURL = [NSURL fileURLWithPath:[[url path] stringByAppendingPathComponent:file]];
			[children addObject:[self itemAtFileURL:childURL rootURL:rootURL]];
		}
	}
	return children;
}

- (NSMutableArray *)childrenAtSftpURL:(NSURL *)url connection:(SFTPConnection *)conn rootURL:(NSURL *)rootURL error:(NSError **)outError
{
	NSMutableArray *children = [[NSMutableArray alloc] init];
	NSArray *entries = [conn contentsOfDirectoryAtPath:[url path] error:outError];
	if (entries == nil)
		return nil;
	SFTPDirectoryEntry *entry;
	for (entry in entries) {
		NSString *file = [entry filename];
		if (![file hasPrefix:@"."] && [skipRegex matchInString:file] == nil) {
			NSURL *childURL = [[NSURL alloc] initWithScheme:[url scheme] host:[conn hostWithUser] path:[[url path] stringByAppendingPathComponent:file]];
			id item = [self itemAtSftpURL:childURL connection:conn rootURL:rootURL attributes:[entry attributes] error:outError];
			if (item == nil)
				return nil;
			[children addObject:item];
		}
	}
	return children;
}

- (NSString *)relativePathForItem:(NSDictionary *)item
{
        NSString *root = [[item objectForKey:@"root"] path];
        NSString *path = [[item objectForKey:@"url"] path];
        if ([path length] > [root length])
                return [path substringWithRange:NSMakeRange([root length] + 1, [path length] - [root length] - 1)];
        return path;
}

- (NSMutableDictionary *)itemAtURL:(NSURL *)url rootURL:(NSURL *)rootURL
{
	NSMutableDictionary *item = [NSMutableDictionary dictionaryWithObjectsAndKeys:url, @"url", rootURL, @"root", nil];
	NSString *relpath = [self relativePathForItem:item];
	[item setObject:relpath forKey:@"relpath"];
	[item setObject:[relpath stringByDeletingLastPathComponent] forKey:@"reldir"];
	[item setObject:[[url path] lastPathComponent] forKey:@"name"];

	return item;
}

- (NSMutableDictionary *)itemAtFileURL:(NSURL *)url rootURL:(NSURL *)rootURL
{
	NSMutableDictionary *item = [self itemAtURL:url rootURL:rootURL];

	BOOL isDirectory = NO;
	if ([[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDirectory] && isDirectory) {
		NSMutableArray *children = [self childrenAtFileURL:url rootURL:rootURL];
		[item setObject:children forKey:@"children"];
	}

	return item;
}

- (NSMutableDictionary *)itemAtSftpURL:(NSURL *)url connection:(SFTPConnection *)conn rootURL:(NSURL *)rootURL attributes:(Attrib *)attributes error:(NSError **)outError
{
	NSMutableDictionary *item = [self itemAtURL:url rootURL:rootURL];

	if (attributes && (attributes->flags & SSH2_FILEXFER_ATTR_PERMISSIONS) && S_ISDIR(attributes->perm)) {
		// It's a directory
		NSMutableArray *children = [self childrenAtSftpURL:url connection:conn rootURL:rootURL error:outError];
		if (children == nil)
			return nil;
		[item setObject:children forKey:@"children"];
	}

	return item;
}

- (NSMutableDictionary *)itemAtSftpURL:(NSURL *)url connection:(SFTPConnection *)conn rootURL:(NSURL *)rootURL error:(NSError **)outError
{
	Attrib *attrs = [conn stat:[url path] error:outError];
	if (attrs == NULL)
		return nil;
	return [self itemAtSftpURL:url connection:conn rootURL:rootURL attributes:attrs error:outError];
}

- (id)addFileURL:(NSURL *)url
{
        id item = [self itemAtFileURL:url rootURL:url];
	[rootItems addObject:item];
	return item;
}

- (id)addSftpURL:(NSURL *)url error:(NSError **)outError
{
	SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:url error:outError];
	if (conn) {
		id item = [self itemAtSftpURL:url connection:conn rootURL:url error:outError];
		if (item)
			[rootItems addObject:item];
                return item;
	}
	return nil;
}

- (void)addURL:(NSURL *)aURL
{
	if ([rootItems indexOfObject:aURL] == NSNotFound && aURL != nil) {
		NSError *error = nil;
		id item = nil;
		if ([[aURL scheme] isEqualToString:@"file"])
			item = [self addFileURL:aURL];
		else if ([[aURL scheme] isEqualToString:@"sftp"])
			item = [self addSftpURL:aURL error:&error];
		else
			error = [SFTPConnection errorWithDescription:[NSString stringWithFormat:@"unhandled scheme %@", [aURL scheme]]];

		if (item) {
			[self filterFiles:self];
			[explorer reloadData];
			[explorer expandItem:item expandChildren:NO];
		} else if (error) {
			NSAlert *alert = [NSAlert alertWithError:error];
			[alert runModal];
		}
	}
}

#pragma mark -
#pragma mark Explorer actions

- (IBAction)actionMenu:(id)sender
{
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
		[self addURL:url];
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
	if ([[[sftpConnectForm cellAtIndex:0] stringValue] length] == 0) {
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

	NSError *error = nil;
	SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithHost:host user:user error:&error];
	if (conn) {
		INFO(@"connected to %@ as %@", host, user);
		if (![path hasPrefix:@"/"]) {
			NSString *pwd = [conn currentDirectory];
			if (pwd == nil) {
				INFO(@"%s", "FAILED to read current directory");
				return;
			}
			path = [NSString stringWithFormat:@"%@/%@", pwd, path];
		}
		NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"sftp://%@@%@%@", user, host, path]];
		[self addURL:url];
	} else {
		INFO(@"FAILED to connect to %@: %@", host, error);
		NSAlert *alert = [NSAlert alertWithError:error];
		[alert runModal];
	}
}

- (IBAction)cancelSftpSheet:(id)sender
{
	[NSApp endSheet:sftpConnectView];
}

- (IBAction)addSFTPLocation:(id)sender
{
	[NSApp beginSheet:sftpConnectView modalForWindow:window modalDelegate:self didEndSelector:@selector(sftpSheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)showExplorerSearch
{
	NSRect frame = [explorerView frame];
	frame.size.height -= 49;
	frame.origin.y += 49;
	[scrollView setFrame:frame];
	[filterField setHidden:NO];
}

- (void)hideExplorerSearch
{
	[filterField setHidden:YES];
	NSRect frame = [explorerView frame];
	frame.size.height -= 23;
	frame.origin.y += 23;
	[scrollView setFrame:frame];
}

- (void)resetExplorerView
{
	[self hideExplorerSearch];
        [filterField setStringValue:@""];
        [self filterFiles:self];
        int i, n = [self outlineView:explorer numberOfChildrenOfItem:nil];
        for (i = 0; i < n; i++)
                [explorer expandItem:[self outlineView:explorer child:i ofItem:nil] expandChildren:NO];
}

- (void)explorerClick:(id)sender
{
	NSIndexSet *set = [explorer selectedRowIndexes];
	if ([set count] > 1)
		return;
	NSDictionary *item = [explorer itemAtRow:[set firstIndex]];
	if (item && ![self outlineView:explorer isItemExpandable:item])
		[delegate goToURL:[item objectForKey:@"url"]];

        [self cancelExplorer];
}

- (void)explorerDoubleClick:(id)sender
{
	NSIndexSet *set = [explorer selectedRowIndexes];
	if ([set count] > 1)
		return;
	NSDictionary *item = [explorer itemAtRow:[set firstIndex]];
	if (item && [self outlineView:explorer isItemExpandable:item]) {
		if ([explorer isItemExpanded:item])
			[explorer collapseItem:item];
		else
			[explorer expandItem:item];
	} else
		[self explorerClick:sender];
}

- (IBAction)searchFiles:(id)sender
{
	if ([splitView isSubviewCollapsed:explorerView]) {
		closeExplorerAfterUse = YES;
		[self toggleExplorer:nil];
	}

	[self showExplorerSearch];
	[window makeFirstResponder:filterField];
}

- (IBAction)toggleExplorer:(id)sender
{
	if ([splitView isSubviewCollapsed:explorerView])
		[splitView setPosition:200 ofDividerAtIndex:0];
	else
		[splitView setPosition:0 ofDividerAtIndex:0];
}

- (void)cancelExplorer
{
	if (closeExplorerAfterUse) {
		[self toggleExplorer:self];
		closeExplorerAfterUse = NO;
	}
	[self resetExplorerView];
	[delegate focusEditor];
}

- (void)markItem:(NSMutableDictionary *)item withFileMatch:(ViRegexpMatch *)fileMatch pathMatch:(ViRegexpMatch *)pathMatch
{
	NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithString:[item objectForKey:@"relpath"]];

	NSUInteger i;
	for (i = 1; i <= [pathMatch count]; i++) {
		NSRange range = [pathMatch rangeOfSubstringAtIndex:i];
		if (range.length > 0)
			[s addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:11.0] range:range];
	}

	NSUInteger offset = [[item objectForKey:@"relpath"] length] - [[item objectForKey:@"name"] length];

	for (i = 1; i <= [fileMatch count]; i++) {
		NSRange range = [fileMatch rangeOfSubstringAtIndex:i];
		if (range.length > 0) {
			range.location += offset;
			[s addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:11.0] range:range];
		}
	}

	[s addAttribute:NSParagraphStyleAttributeName value:matchParagraphStyle range:NSMakeRange(0, [s length])];

	[item setObject:s forKey:@"match"];
}

/* From fuzzy_file_finder.rb by Jamis Buck (public domain).
 *
 * Determine the score of this match.
 * 1. fewer "inside runs" (runs corresponding to the original pattern)
 *    is better.
 * 2. better coverage of the actual path name is better
 */
- (double)scoreForMatch:(ViRegexpMatch *)match inSegments:(int)nsegments
{
	NSUInteger totalLength = [match rangeOfMatchedString].length;

	NSUInteger insideLength = 0;
	NSUInteger i;
	for (i = 1; i < [match count]; i++)
		insideLength += [match rangeOfSubstringAtIndex:i].length;

	double run_ratio = ([match count] == 1) ? 1 : (double)nsegments / (double)([match count] - 1);
	double char_ratio = (insideLength == 0 || totalLength == 0) ? 1 : (double)insideLength / (double)totalLength;

	return run_ratio * char_ratio;
}

- (void)expandItems:(NSArray *)items
	  intoArray:(NSMutableArray *)expandedArray
	 pathRx:(ViRegexp *)pathRx
	 fileRx:(ViRegexp *)fileRx
{
	NSString *reldir = nil;
	ViRegexpMatch *pathMatch ;
	double pathScore;

	NSMutableDictionary *item;
	for (item in items) {
		if ([self outlineView:explorer isItemExpandable:item])
			[self expandItems:[item objectForKey:@"children"] intoArray:expandedArray pathRx:pathRx fileRx:fileRx];
		else {
			if (reldir == nil) {
				reldir = [item objectForKey:@"reldir"];
				if ((pathMatch = [pathRx matchInString:reldir]) != nil) {
					pathScore = [self scoreForMatch:pathMatch inSegments:[reldir occurrencesOfCharacter:'/'] + 1];
					// INFO(@"path %@ = %lf, total Length = %u", reldir, pathScore, (unsigned)[pathMatch rangeOfMatchedString].length);
				}
			}

			if (pathMatch != nil) {
				NSString *name = [item objectForKey:@"name"];
				ViRegexpMatch *fileMatch;
				if ((fileMatch = [fileRx matchInString:name]) != nil) {
					double fileScore = [self scoreForMatch:fileMatch inSegments:1];
					// INFO(@"%@ = %lf * %lf = %lf", [item objectForKey:@"relpath"], pathScore, fileScore, pathScore * fileScore);

					[self markItem:item withFileMatch:fileMatch pathMatch:pathMatch];
					[item setObject:[NSNumber numberWithDouble:pathScore * fileScore] forKey:@"score"];
					[expandedArray addObject:item];
				}
			}
		}
	}
}

- (void)appendFilter:(NSString *)filter toPattern:(NSMutableString *)pattern
{
	NSUInteger i;
	for (i = 0; i < [filter length]; i++) {
		unichar c = [filter characterAtIndex:i];
		if (i != 0)
			[pattern appendString:@"[^/]*?"];
		[pattern appendFormat:@"(%s%C)", c == '.' ? "\\" : "", c];
	}
}

static NSInteger
sort_by_score(id a, id b, void *context)
{
	double a_score = [[(NSDictionary *)a objectForKey:@"score"] doubleValue];
	double b_score = [[(NSDictionary *)b objectForKey:@"score"] doubleValue];

	if (a_score < b_score)
		return NSOrderedDescending;
	else if (a_score > b_score)
		return NSOrderedAscending;
	return NSOrderedSame;
}

- (IBAction)filterFiles:(id)sender
{
	NSString *filter = [filterField stringValue];

	if ([filter length] == 0)
                filteredItems = [[NSMutableArray alloc] initWithArray:rootItems];
	else {
		NSArray *components = [filter componentsSeparatedByString:@"/"];

		NSMutableString *pathPattern = [NSMutableString string];
		[pathPattern appendString:@"^.*?"];
		NSUInteger i;
		for (i = 0; i < [components count] - 1; i++) {
			if (i != 0)
				[pathPattern appendString:@".*?/.*?"];
			[self appendFilter:[components objectAtIndex:i] toPattern:pathPattern];
		}
		[pathPattern appendString:@".*?$"];
                ViRegexp *pathRx = [ViRegexp regularExpressionWithString:pathPattern options:ONIG_OPTION_IGNORECASE];

                NSMutableString *filePattern = [NSMutableString string];
		[filePattern appendString:@"^.*?"];
		[self appendFilter:[components lastObject] toPattern:filePattern];
		[filePattern appendString:@".*$"];
                ViRegexp *fileRx = [ViRegexp regularExpressionWithString:filePattern options:ONIG_OPTION_IGNORECASE];

                filteredItems = [[NSMutableArray alloc] init];
                [self expandItems:rootItems intoArray:filteredItems pathRx:pathRx fileRx:fileRx];

		[filteredItems sortUsingFunction:sort_by_score context:nil];
        }
        [explorer reloadData];
	[explorer selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
}

#pragma mark -

- (BOOL)control:(NSControl *)sender textView:(NSTextView *)textView doCommandBySelector:(SEL)aSelector
{
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
			[explorer selectRowIndexes:[NSIndexSet indexSetWithIndex:row - 1] byExtendingSelection:NO];
		return YES;
	} else if (aSelector == @selector(moveDown:)) { // down arrow
		NSInteger row = [explorer selectedRow];
		if (row + 1 < [explorer numberOfRows])
			[explorer selectRowIndexes:[NSIndexSet indexSetWithIndex:row + 1] byExtendingSelection:NO];
		return YES;
	} else if (aSelector == @selector(moveRight:)) { // right arrow
		NSInteger row = [explorer selectedRow];
		id item = [explorer itemAtRow:row];
		if (item && [self outlineView:explorer isItemExpandable:item])
			[explorer expandItem:item];
		return YES;
	} else if (aSelector == @selector(moveLeft:)) { // left arrow
		NSInteger row = [explorer selectedRow];
		id item = [explorer itemAtRow:row];
		if (item == nil)
			return YES;
		if ([self outlineView:explorer isItemExpandable:item] && [explorer isItemExpanded:item])
			[explorer collapseItem:item];
		else {
			id parent = [explorer parentForItem:item];
			if (parent)
				[explorer selectRowIndexes:[NSIndexSet indexSetWithIndex:[explorer rowForItem:parent]] byExtendingSelection:NO];
		}
		return YES;
	} else if (aSelector == @selector(cancelOperation:)) { // escape
		[self cancelExplorer];
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

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if ([[filterField stringValue] length] > 0) {
		id match = [item objectForKey:@"match"];
		return match ?: [item objectForKey:@"relpath"];
        } else
                return [item objectForKey:@"name"];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
	return NO;
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
	return 18;
}

- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	NSCell *cell = [tableColumn dataCellForRow:[explorer rowForItem:item]];
	if (cell) {
		NSURL *url = [item objectForKey:@"url"];
		NSImage *img;
		if ([url isFileURL])
			img = [[NSWorkspace sharedWorkspace] iconForFile:[url path]];
		else {
			if ([self outlineView:outlineView isItemExpandable:item])
				img = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode('fldr')];
			else
				img = [[NSWorkspace sharedWorkspace] iconForFileType:[[url path] pathExtension]];
		}

		[cell setFont:[NSFont systemFontOfSize:11.0]];
		[img setSize:NSMakeSize(16, 16)];
		[cell setImage:img];
	}

	return cell;
}

@end
