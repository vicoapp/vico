#import "MyDocument.h"
#import "PSMTabBarControl/PSMTabBarControl.h"

@interface MyDocument (private)
- (void)newTab;
@end

@implementation MyDocument

- (id)init
{
	self = [super init];
	if (self)
	{
		// Add your subclass-specific initialization here.
		// If an error occurs here, send a [self release] message and return nil.
	}
	return self;
}

- (NSString *)windowNibName
{
	return @"MyDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
	[super windowControllerDidLoadNib:aController];

	// remove all tabs from the tab view
	while ([tabView numberOfTabViewItems] > 0)
		[tabView removeTabViewItem:[tabView tabViewItemAtIndex:0]];

	// configure the tab bar control
	PSMTabBarControl *tabBar = [tabView delegate];
	[tabBar setStyleNamed:@"Unified"];
	[tabBar setCanCloseOnlyTab:YES];
	[tabBar setAllowsDragBetweenWindows:YES];

	// hook up add tab button
	[tabBar setShowAddTabButton:YES];
	[[tabBar addTabButton] setTarget:self];
	[[tabBar addTabButton] setAction:@selector(addNewTab:)];
	
	// add the first editor view
	[self newTab];
	[self setFileURL:initialFileURL];
	initialFileURL = nil;
	[self setFileModificationDate:initialFileModificationDate];
	initialFileModificationDate = nil;

	readContent = nil;
}

- (ViEditController *)currentEditor
{
	return [[tabView selectedTabViewItem] identifier];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	// Insert code here to write your document to data of the specified type. If
	// the given outError != NULL, ensure that you set *outError when returning nil.

	return [[self currentEditor] saveData];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	// Insert code here to read your document from the given data of the
	// specified type. If the given outError != NULL, ensure that you set *outError
	// when returning NO.

	readContent = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if ([self currentEditor])
	{
		[[self currentEditor] setString:readContent];
		readContent = nil;
	}

	return YES;
}

- (void)changeTheme:(ViTheme *)theme
{
	// loop over each tab and change theme for each delegate
	NSTabViewItem *item;
	for (item in [tabView tabViewItems])
	{
		[[item identifier] changeTheme:theme];
	}
}

- (void)setPageGuide:(int)pageGuideValue
{
	// loop over each tab and change the value for each delegate
	NSTabViewItem *item;
	for (item in [tabView tabViewItems])
	{
		[[item identifier] setPageGuide:pageGuideValue];
	}
}

// Each editor in each tab has its own undo manager. Return the current one.
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
	return [[self currentEditor] undoManager];
}

- (NSWindow *)window
{
	return documentWindow;
}

- (void)setFileURL:(NSURL *)aURL
{
	if (aURL)
	{
		if ([self currentEditor])
			[[self currentEditor] setFileURL:aURL];
		else
			initialFileURL = aURL;
	}

	[super setFileURL:aURL];
	[[tabView selectedTabViewItem] setLabel:[self displayName]];
}

- (NSURL *)fileURL
{
	if ([self currentEditor])
	{
		return [[self currentEditor] fileURL];
	}
	else
	{
		return initialFileURL;
	}
}

- (void)canCloseDocumentWithDelegate:(id)delegate shouldCloseSelector:(SEL)shouldCloseSelector contextInfo:(void *)contextInfo
{
	[super canCloseDocumentWithDelegate:delegate shouldCloseSelector:shouldCloseSelector contextInfo:contextInfo];
}

- (NSString *)displayName
{
	if ([self fileURL])
		return [[[self fileURL] path] lastPathComponent];
	return @"New file";
}

- (ViEditController *)openFileInTab:(NSString *)path
{
	NSString *standardizedPath = [path stringByStandardizingPath];

	if (path)
	{
		/* first check if the file is already opened */
		NSTabViewItem *item;
		for (item in [tabView tabViewItems])
		{
			ViEditController *editor = [item identifier];
			if ([standardizedPath isEqualToString:[[editor fileURL] path]])
			{
				[tabView selectTabViewItem:item];
				return editor;
			}
		}
	}

	[self newTab];

	if (path)
	{
		NSURL *url = [NSURL fileURLWithPath:standardizedPath];
		NSError *error = nil;
		[self readFromURL:url ofType:nil error:&error];
		[self setFileURL:url];
		if (error)
			[NSApp presentError:error];
		else
			return [self currentEditor];
	}
	
	return nil;
}

- (ViTagStack *)sharedTagStack
{
	if (tagStack == nil)
		tagStack = [[ViTagStack alloc] init];
	return tagStack;
}

- (IBAction)toggleProjectDrawer:(id)sender
{
	[projectDrawer toggle:sender];
}

- (NSDate *)fileModificationDate
{
	return [[self currentEditor] fileModificationDate];
}

- (void)setFileModificationDate:(NSDate *)modificationDate
{
	if ([self currentEditor])
		return [[self currentEditor] setFileModificationDate:modificationDate];
	else
		initialFileModificationDate = modificationDate;
}

- (NSString *)autosavingFileType
{
	/* disable autosaving */
	return nil;
}

#pragma mark -
#pragma mark TabView helper methods

- (void)newTab
{
	ViEditController *editor = [[ViEditController alloc] initWithString:readContent];
	[editor setDelegate:self];

	// create a new tab
	NSTabViewItem *tab = [[NSTabViewItem alloc] initWithIdentifier:editor];
	[tab setView:[editor view]];
	[tabView addTabViewItem:tab];
	[tabView selectTabViewItem:tab];
}

- (void)addNewTab:(id)sender
{
	[self newTab];
}

- (void)document:(NSDocument *)doc shouldCloseTab:(BOOL)shouldClose contextInfo:(void *)contextInfo
{
	if (shouldClose)
	{
		if ([tabView numberOfTabViewItems] <= 1)
			[self close];
		else
			[tabView removeTabViewItem:[tabView selectedTabViewItem]];
	}
}

- (IBAction)closeCurrentTab:(id)sender
{
	INFO(@"closing current tab");
	[self canCloseDocumentWithDelegate:self shouldCloseSelector:@selector(document:shouldCloseTab:contextInfo:) contextInfo:nil];
}

- (void)selectTab:(int)tab
{
	if (tab < [tabView numberOfTabViewItems])
		[tabView selectTabViewItem:[[[tabView delegate] representedTabViewItems] objectAtIndex:tab]];
}

- (void)selectNextTab
{
	int num = [tabView numberOfTabViewItems];
	if (num <= 1)
		return;

	int ndx = [tabView indexOfTabViewItem:[tabView selectedTabViewItem]];
	if (++ndx >= num)
		ndx = 0;
	[tabView selectTabViewItem:[tabView tabViewItemAtIndex:ndx]];
}

- (void)selectPreviousTab
{
	int num = [tabView numberOfTabViewItems];
	if (num <= 1)
		return;

	int ndx = [tabView indexOfTabViewItem:[tabView selectedTabViewItem]];
	if (--ndx < 0)
		ndx = num - 1;
	[tabView selectTabViewItem:[tabView tabViewItemAtIndex:ndx]];
}

#pragma mark -
#pragma mark TabView delegate methods

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	[documentWindow setTitle:[self displayName]];
	[self setUndoManager:[[self currentEditor] undoManager]];
	[super setFileURL:[self fileURL]];
}

- (BOOL)tabView:(NSTabView *)aTabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
	[tabView selectTabViewItem:tabViewItem];
	[self closeCurrentTab:self];
	return NO;
}

- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)aTabView
{
	/* Go through all tabs and reset all edit controllers delegates to self.
	 * Needed after a tab drag from another document window.
	 */

	NSTabViewItem *item;
	for (item in [aTabView tabViewItems])
	{
		id oldDelegate = [[item identifier] delegate];
		INFO(@"old delegate for %@ = %@", [self displayName], oldDelegate);
		INFO(@"new delegate for %@ = %@", [self displayName], self);
		[[item identifier] setDelegate:self];
	}
}

@end
