#import "MyDocument.h"
#import "PSMTabBarControl/PSMTabBarControl.h"

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

	// add the first editor view
	ViEditController *editor = [[ViEditController alloc] initWithString:readContent];
	[editor setFilename:[self fileURL]];

	// create a new tab
	NSTabViewItem *item = [[NSTabViewItem alloc] initWithIdentifier:editor];
	[item setView:[editor view]];
	[item setLabel:[[[self fileURL] path] lastPathComponent]];
	[tabView addTabViewItem:item];
	[tabView selectTabViewItem:item];

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
	NSTabViewItem *item = [tabView selectedTabViewItem];
	if(item)
	{
		[[item identifier] setString:readContent];
		readContent = nil;
	}

	return YES;
}

- (void)changeTheme:(ViTheme *)theme
{
	// FIXME: loop over each tab and change theme for each delegate
}

// Each editor in each tab has its own undo manager. Return the current one.
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
	return [[self currentEditor] undoManager];
}

@end
