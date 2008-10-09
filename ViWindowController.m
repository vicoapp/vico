#import "ViWindowController.h"
#import <PSMTabBarControl/PSMTabBarControl.h>
#import "ViDocument.h"

static NSMutableArray		*windowControllers = nil;
static NSWindowController	*currentWindowController = nil;

@implementation ViWindowController

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
	if (self)
	{
		[self setShouldCascadeWindows:NO];
		isLoaded = NO;
		if (windowControllers == nil)
			windowControllers = [[NSMutableArray alloc] init];
		[windowControllers addObject:self];
		currentWindowController = self;
	}

	return self;
}

- (void)windowDidLoad
{
	INFO(@"window %@ did load", self);

	NSArray *existingItems;
	NSEnumerator *enumerator;
	NSTabViewItem *item;

	[[tabBar addTabButton] setTarget:self];
	[[tabBar addTabButton] setAction:@selector(addNewDocumentTab:)];
	[tabBar setStyleNamed:@"Unified"];
	[tabBar setCanCloseOnlyTab:NO];
	[tabBar setHideForSingleTab:NO];
	[tabBar setPartnerView:tabView];
	[tabBar setShowAddTabButton:YES];
	[tabBar setAllowsDragBetweenWindows:NO];

	existingItems = [tabView tabViewItems];
	enumerator = [existingItems objectEnumerator];
	while ((item = [enumerator nextObject]) != nil)
	{
		[tabView removeTabViewItem:item];
	}

	isLoaded = YES;
	if (initialDocument)
		[self addNewTab:initialDocument];
	[[self window] setDelegate:self];
	[[self window] setFrameUsingName:@"MainDocumentWindow"];

	[[self window] makeKeyAndOrderFront:self];
}

- (void)setDocument:(NSDocument *)document
{
	[super setDocument:document];
}

- (IBAction)addNewDocumentTab:(id)sender
{
	[[NSDocumentController sharedDocumentController] newDocument:self];
}

- (void)addNewTab:(ViDocument *)document
{
	if (!isLoaded)
	{
		initialDocument = document;
		return;
	}

	NSTabViewItem *newItem = [[NSTabViewItem alloc] initWithIdentifier:document];

	[NSBundle loadNibNamed:[document windowNibName] owner:document];
	[document windowControllerDidLoadNib:self];
	[newItem setView:[document view]];
	[newItem setLabel:[document displayName]];
	[tabView addTabViewItem:newItem];
	[tabView selectTabViewItem:newItem];
}

#if 0
- (IBAction)addNewTab:(id)sender
{
	PlainDocumentView	*plainDocView;
	NSTabViewItem		*newItem;
	
	if (!isLoaded) return;
    plainDocView = [[[PlainDocumentView alloc] initWithFrame:[tabView frame]] autorelease];
	newItem = [[[NSTabViewItem alloc] initWithIdentifier:[plainDocView controller]] autorelease];
	[newItem setView:plainDocView];
	[[plainDocView textView] setString:text withExtension:extension];
	[text release];
	[extension release];
	text = nil;
	extension = nil;
	[plainDocView setDocument:[self document]];
    [newItem setLabel:[[self document] displayName]];
    [tabView addTabViewItem:newItem];
    [tabView selectTabViewItem:newItem];
}
#endif


- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	if (!isLoaded)
		return;

	[[self document] removeWindowController:self];
	ViDocument *doc = [tabViewItem identifier];
	[doc addWindowController:self];
	[self setDocument:doc];
}

- (void)closeCurrentTabViewItem
{
	NSTabViewItem *tabViewItem;
	
	tabViewItem = [tabView selectedTabViewItem];
	INFO(@"close tabview %@", tabViewItem);
	//[(ViDocument *)[[tabViewItem identifier] valueForKeyPath:@"selection.document"] tryToCloseSingleDocument];
}

- (BOOL)tabView:(NSTabView *)aTabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
	[tabView selectTabViewItem:tabViewItem];
	INFO(@"close tabview %@", tabViewItem);
	//[(ViDocument *)[[tabViewItem identifier] valueForKeyPath:@"selection.document"] tryToCloseSingleDocument];
	return NO;
}

- (int)numberOfTabViewItems
{
	return [tabView numberOfTabViewItems];
}

- (void)removeTabViewItemContainingDocument:(ViDocument *)doc
{
	[tabView removeTabViewItem:[self tabViewItemForDocument:doc]];
}

- (NSTabViewItem *)tabViewItemForDocument:(ViDocument *)doc
{
	int count = [tabView numberOfTabViewItems];
	int i;
	for (i = 0; i < count; i++)
	{
		NSTabViewItem *item = [tabView tabViewItemAtIndex:i];
		if ([item identifier] == doc)
			return item;
	}

	return nil;
}

- (void)windowDidResize:(NSNotification *)aNotification
{
	[[self window] saveFrameUsingName:@"MainDocumentWindow"];
}

- (void)windowDidBecomeMain:(NSNotification *)aNotification
{
	currentWindowController = self;
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	if (currentWindowController == self)
		currentWindowController = nil;
	[windowControllers removeObject:self];
	[tabBar setDelegate:nil];
}

- (ViDocument *)currentDocument
{
	return [[tabView selectedTabViewItem] identifier];
}

- (void)selectDocument:(ViDocument *)document
{
	NSTabViewItem *item = [self tabViewItemForDocument:document];
	if (item)
		[tabView selectTabViewItem:item];
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

@end

