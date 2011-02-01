#import "ProjectDelegate.h"
#import "logging.h"
#import "MHTextIconCell.h"
#import "SFTPConnectionPool.h"
#import "ViWindowController.h" // for goToUrl:

@interface ProjectDelegate (private)
+ (NSArray *)childrenAtURL:(NSURL *)url error:(NSError **)outError;
+ (NSArray *)childrenAtFileURL:(NSURL *)url error:(NSError **)outError;
+ (NSArray *)childrenAtSftpURL:(NSURL *)url error:(NSError **)outError;
- (NSString *)relativePathForItem:(NSDictionary *)item;
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item;
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item;
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)anIndex ofItem:(id)item;
- (void)cancelExplorer;
@end

@implementation ProjectFile

@synthesize score, markedString;

- (id)initWithURL:(NSURL *)aURL
{
	self = [super init];
	if (self) {
		url = aURL;
	}
	return self;
}

- (id)initWithURL:(NSURL *)aURL entry:(SFTPDirectoryEntry *)anEntry
{
	self = [super init];
	if (self) {
		url = aURL;
		entry = anEntry;
	}
	return self;
}

+ (id)fileWithURL:(NSURL *)aURL
{
	return [[ProjectFile alloc] initWithURL:aURL];
}

+ (id)fileWithURL:(NSURL *)aURL sftpInfo:(SFTPDirectoryEntry *)entry
{
	return [[ProjectFile alloc] initWithURL:aURL entry:entry];
}

- (BOOL)isDirectory
{
	if ([url isFileURL]) {
		BOOL isDirectory = NO;
		if ([[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDirectory] && isDirectory)
			return YES;
		return NO;
	} else {
		return [entry isDirectory];
	}
}

- (NSURL *)url
{
	return url;
}

- (NSArray *)children
{
	if (children == nil) {
		NSError *error = nil;
		children = [ProjectDelegate childrenAtURL:url error:&error];
		if (error)
			INFO(@"error: %@", [error localizedDescription]);
	}
	return children;
}

- (NSString *)name
{
	return [url lastPathComponent];
}

- (NSString *)pathRelativeToURL:(NSURL *)relURL
{
        NSString *root = [relURL path];
        NSString *path = [url path];
        if ([path length] > [root length])
                return [path substringWithRange:NSMakeRange([root length] + 1, [path length] - [root length] - 1)];
        return path;
}

@end

@implementation ProjectDelegate

@synthesize delegate;

- (id)init
{
	self = [super init];
	if (self) {
		rootItems = [NSArray array];
		skipRegex = [ViRegexp regularExpressionWithString:[[NSUserDefaults standardUserDefaults] stringForKey:@"skipPattern"]];

		matchParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		[matchParagraphStyle setLineBreakMode:NSLineBreakByTruncatingMiddle];
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
	[cell setLineBreakMode:NSLineBreakByTruncatingMiddle];
	[cell setWraps:NO];

	[[sftpConnectForm cellAtIndex:1] setPlaceholderString:NSUserName()];

	[rootButton setTarget:self];
	[rootButton setAction:@selector(changeRoot:)];
}

- (void)changeRoot:(id)sender
{
	[self browseURL:[[sender clickedPathComponentCell] URL]];
}

+ (NSArray *)childrenAtURL:(NSURL *)url error:(NSError **)outError
{
	if ([url isFileURL])
		return [self childrenAtFileURL:url error:outError];
	else if ([[url scheme] isEqualToString:@"sftp"])
		return [self childrenAtSftpURL:url error:outError];
	else if (outError)
		*outError = [SFTPConnection errorWithFormat:@"unhandled scheme %@", [url scheme]];
	return nil;
}

+ (NSArray *)childrenAtFileURL:(NSURL *)url error:(NSError **)outError
{
	NSFileManager *fm = [NSFileManager defaultManager];

	NSArray *files = [fm contentsOfDirectoryAtPath:[url path] error:outError];
	if (files == nil)
		return nil;

	ViRegexp *skipRegex = [ViRegexp regularExpressionWithString:[[NSUserDefaults standardUserDefaults] stringForKey:@"skipPattern"]];

	NSMutableArray *children = [[NSMutableArray alloc] init];
	for (NSString *filename in files)
		if (![filename hasPrefix:@"."] && [skipRegex matchInString:filename] == nil)
			[children addObject:[ProjectFile fileWithURL:[url URLByAppendingPathComponent:filename]]];

	return children;
}

+ (NSArray*)childrenAtSftpURL:(NSURL*)url error:(NSError **)outError
{
	SFTPConnection *conn = [[SFTPConnectionPool sharedPool] connectionWithURL:url error:outError];
	if (conn == nil)
		return nil;

	NSArray *entries = [conn contentsOfDirectoryAtPath:[url path] error:outError];
	if (entries == nil)
		return nil;

	ViRegexp *skipRegex = [ViRegexp regularExpressionWithString:[[NSUserDefaults standardUserDefaults] stringForKey:@"skipPattern"]];

	NSMutableArray *children = [[NSMutableArray alloc] init];
	SFTPDirectoryEntry *entry;
	for (entry in entries) {
		NSString *filename = [entry filename];
		if (![filename hasPrefix:@"."] && [skipRegex matchInString:filename] == nil)
			[children addObject:[ProjectFile fileWithURL:[url URLByAppendingPathComponent:filename] sftpInfo:entry]];
	}
	
	return children;
}

- (void)browseURL:(NSURL *)aURL
{
	NSError *error = nil;
	NSArray *children = nil;

	children = [ProjectDelegate childrenAtURL:aURL error:&error];

	if (children) {
		rootItems = children;
		[self filterFiles:self];
		[explorer reloadData];
		[rootButton setURL:aURL];
	} else if (error) {
		NSAlert *alert = [NSAlert alertWithError:error];
		[alert runModal];
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
		[self browseURL:url];
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
		if (![path hasPrefix:@"/"])
			path = [NSString stringWithFormat:@"%@/%@", [conn home], path];
		NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"sftp://%@@%@%@", user, host, path]];
		[self browseURL:url];
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
	frame.size.height -= 49 + 22;
	frame.origin.y += 49;
	[scrollView setFrame:frame];
	[filterField setHidden:NO];
}

- (void)hideExplorerSearch
{
	[filterField setHidden:YES];
	NSRect frame = [explorerView frame];
	frame.size.height -= 23 + 22;
	frame.origin.y += 23;
	[scrollView setFrame:frame];
}

- (void)resetExplorerView
{
	[self hideExplorerSearch];
        [filterField setStringValue:@""];
        [self filterFiles:self];
#if 0
        int i, n = [self outlineView:explorer numberOfChildrenOfItem:nil];
        for (i = 0; i < n; i++)
                [explorer expandItem:[self outlineView:explorer child:i ofItem:nil] expandChildren:NO];
#endif
}

- (void)explorerClick:(id)sender
{
	NSIndexSet *set = [explorer selectedRowIndexes];
	if ([set count] > 1)
		return;

	ProjectFile *item = [explorer itemAtRow:[set firstIndex]];
	if (item && ![self outlineView:explorer isItemExpandable:item]) {
		[delegate goToURL:[item url]];
		[self cancelExplorer];
	}
}

- (void)explorerDoubleClick:(id)sender
{
	NSIndexSet *set = [explorer selectedRowIndexes];
	if ([set count] > 1)
		return;
	ProjectFile *item = [explorer itemAtRow:[set firstIndex]];
	if (item && [self outlineView:explorer isItemExpandable:item]) {
		[self browseURL:[item url]];
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

- (void)markItem:(ProjectFile *)item withFileMatch:(ViRegexpMatch *)fileMatch pathMatch:(ViRegexpMatch *)pathMatch
{
	NSString *relpath = [item pathRelativeToURL:[rootButton URL]];
	NSMutableAttributedString *s = [[NSMutableAttributedString alloc] initWithString:relpath];

	NSUInteger i;
	for (i = 1; i <= [pathMatch count]; i++) {
		NSRange range = [pathMatch rangeOfSubstringAtIndex:i];
		if (range.length > 0)
			[s addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:11.0] range:range];
	}

	NSUInteger offset = [relpath length] - [[item name] length];

	for (i = 1; i <= [fileMatch count]; i++) {
		NSRange range = [fileMatch rangeOfSubstringAtIndex:i];
		if (range.length > 0) {
			range.location += offset;
			[s addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:11.0] range:range];
		}
	}

	[s addAttribute:NSParagraphStyleAttributeName value:matchParagraphStyle range:NSMakeRange(0, [s length])];

	[item setMarkedString:s];
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

	/*
	 * FIXME: transform into breadth-first search, and limit
	 * number of descended directories (might be different for
	 * file and sftp urls).
	 */

	ProjectFile *item;
	for (item in items) {
		if ([self outlineView:explorer isItemExpandable:item])
			[self expandItems:[item children] intoArray:expandedArray pathRx:pathRx fileRx:fileRx];
		else {
			if (reldir == nil) {
				reldir = [item pathRelativeToURL:[rootButton URL]];
				if ((pathMatch = [pathRx matchInString:reldir]) != nil) {
					pathScore = [self scoreForMatch:pathMatch inSegments:[reldir occurrencesOfCharacter:'/'] + 1];
					// INFO(@"path %@ = %lf, total Length = %u", reldir, pathScore, (unsigned)[pathMatch rangeOfMatchedString].length);
				}
			}

			if (pathMatch != nil) {
				ViRegexpMatch *fileMatch;
				if ((fileMatch = [fileRx matchInString:[item name]]) != nil) {
					double fileScore = [self scoreForMatch:fileMatch inSegments:1];
					// INFO(@"%@ = %lf * %lf = %lf", [item objectForKey:@"relpath"], pathScore, fileScore, pathScore * fileScore);

					[self markItem:item withFileMatch:fileMatch pathMatch:pathMatch];
					[item setScore:pathScore * fileScore];
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
	double a_score = [(ProjectFile *)a score];
	double b_score = [(ProjectFile *)b score];

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
	return [[(ProjectFile *)item children] objectAtIndex:anIndex];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return [(ProjectFile *)item isDirectory];
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if (item == nil)
		return [filteredItems count];

	return [[(ProjectFile *)item children] count];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if ([[filterField stringValue] length] > 0)
		return [item markedString];
        else
		return [(ProjectFile *)item name];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
	return NO;
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
	return 20;
}

- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	NSCell *cell = [tableColumn dataCellForRow:[explorer rowForItem:item]];
	if (cell) {
		NSURL *url = [item url];
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
