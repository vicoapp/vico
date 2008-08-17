#import "MyDocument.h"
#import "PSMTabBarControl/PSMTabBarControl.h"

@interface MyDocument (private)
- (void)newTab;
@end

@implementation MyDocument

- (id)init
{
	self = [super init];
	if(self)
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
	while([tabView numberOfTabViewItems] > 0)
		[tabView removeTabViewItem:[tabView tabViewItemAtIndex:0]];

	// configure the tab bar control
	PSMTabBarControl *tabBar = [tabView delegate];
	[tabBar setStyleNamed:@"Unified"];
	[tabBar setCanCloseOnlyTab:YES];

	// add the first editor view
	[self newTab];
	[self setFileURL:[self fileURL]];

	readContent = nil;

	//[projectDrawer open];
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

#if 0
	if ( outError != NULL )
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
	return nil;
#endif
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	// Insert code here to read your document from the given data of the
	// specified type. If the given outError != NULL, ensure that you set *outError
	// when returning NO.

	readContent = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if([self currentEditor])
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
	for(item in [tabView tabViewItems])
	{
		NSLog(@"got tab view item [%@], identifier = [%@]", item, [item identifier]);
		[[item identifier] changeTheme:theme];
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

- (void)newTab
{
	ViEditController *editor = [[ViEditController alloc] initWithString:readContent];
	[editor setDelegate:self];
	
	// create a new tab
	NSTabViewItem *item = [[NSTabViewItem alloc] initWithIdentifier:editor];
	[item setView:[editor view]];
	[tabView addTabViewItem:item];
	[tabView selectTabViewItem:item];
}

- (void)setFileURL:(NSURL *)aURL
{
	[super setFileURL:aURL];
	if(aURL)
	{
		[[self currentEditor] setFilename:aURL];
		[[tabView selectedTabViewItem] setLabel:[[aURL path] lastPathComponent]];
	}
	else
		[[tabView selectedTabViewItem] setLabel:@"New file"];
}

- (NSURL *)fileURL
{
	NSURL *url = [[self currentEditor] fileURL];
	if(url == nil)
		url = [super fileURL];
	return url;
}

- (void)document:(NSDocument *)doc shouldCloseTab:(BOOL)shouldClose  contextInfo:(void  *)contextInfo
{
	if(shouldClose)
	{
		if([tabView numberOfTabViewItems] <= 1)
			[self close];
		else
			[tabView removeTabViewItem:[tabView selectedTabViewItem]];
	}
}

- (void)canCloseDocumentWithDelegate:(id)delegate shouldCloseSelector:(SEL)shouldCloseSelector contextInfo:(void *)contextInfo
{
	NSLog(@"canCloseDocumentWithDelegate?");
	[super canCloseDocumentWithDelegate:delegate shouldCloseSelector:shouldCloseSelector contextInfo:contextInfo];
}

- (void)closeCurrentTab
{
	[self canCloseDocumentWithDelegate:self shouldCloseSelector:@selector(document:shouldCloseTab:contextInfo:) contextInfo:nil];
}

- (NSString *)displayName
{
	return [[[self fileURL] path] lastPathComponent];
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	NSLog(@"selected tab view item [%@]", tabViewItem);
	[documentWindow setTitle:[self displayName]];
	// [self setFileURL:[self fileURL]];
	[self setUndoManager:[[self currentEditor] undoManager]];
}

- (BOOL)tabView:(NSTabView *)tabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
	[self closeCurrentTab];
	return NO;
}

- (ViEditController *)openFileInTab:(NSString *)path
{
	NSString *standardizedPath = [path stringByStandardizingPath];

	if(path)
	{
		NSLog(@"looking for [%@] = [%@]", path, standardizedPath);
		
		/* first check if the file is already opened */
		NSTabViewItem *item;
		for(item in [tabView tabViewItems])
		{
			ViEditController *editor = [item identifier];
			NSLog(@"  checking [%@]", [[editor fileURL] path]);
			if([standardizedPath isEqualToString:[[editor fileURL] path]])
			{
				[self selectTabViewItem:item];
				return editor;
			}
		}
	}

	[self newTab];

	if(path)
	{
		NSURL *url = [NSURL fileURLWithPath:standardizedPath];
		NSError *error = nil;
		[self readFromURL:url ofType:nil error:&error];
		[self setFileURL:url];
		if(error)
			[NSApp presentError:error];
		else
			return [self currentEditor];
	}
	
	return nil;
}

- (ViTagStack *)sharedTagStack
{
	if(tagStack == nil)
		tagStack = [[ViTagStack alloc] init];
	return tagStack;
}

- (void)selectNextTab
{
	int num = [tabView numberOfTabViewItems];
	if(num <= 1)
		return;

	int ndx = [tabView indexOfTabViewItem:[tabView selectedTabViewItem]];
	if(++ndx >= num)
		ndx = 0;
	[self selectTabViewItem:[tabView tabViewItemAtIndex:ndx]];
}

- (void)selectPreviousTab
{
	int num = [tabView numberOfTabViewItems];
	if(num <= 1)
		return;

	int ndx = [tabView indexOfTabViewItem:[tabView selectedTabViewItem]];
	if(--ndx < 0)
		ndx = num - 1;
	[self selectTabViewItem:[tabView tabViewItemAtIndex:ndx]];
}

- (void)selectTab:(int)tab
{
	if(tab < [tabView numberOfTabViewItems])
		[self selectTabViewItem:[tabView tabViewItemAtIndex:tab]];
}


- (void)selectTabViewItem:(NSTabViewItem *)anItem
{
	[tabView selectTabViewItem:anItem];
	[self setFileURL:[[anItem identifier] fileURL]];
}

@end
