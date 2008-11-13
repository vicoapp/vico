#import "ViWindowController.h"
#import <PSMTabBarControl/PSMTabBarControl.h>
#import "ViDocument.h"
#import "ExTextView.h"

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
	[toolbar setDelegate:self];
	[[self window] setToolbar:toolbar];

	[[tabBar addTabButton] setTarget:self];
	[[tabBar addTabButton] setAction:@selector(addNewDocumentTab:)];
	[tabBar setStyleNamed:@"Unified"];
	[tabBar setCanCloseOnlyTab:YES];
	[tabBar setHideForSingleTab:NO];
	[tabBar setPartnerView:tabView];
	[tabBar setShowAddTabButton:YES];
	[tabBar setAllowsDragBetweenWindows:YES];

	NSTabViewItem *item;
	for (item in [tabView tabViewItems])
	{
		[tabView removeTabViewItem:item];
	}

	isLoaded = YES;
	if (initialDocument)
	{
		[self addNewTab:initialDocument];
                lastDocument = initialDocument;
	}
	[[self window] setDelegate:self];
	[[self window] setFrameUsingName:@"MainDocumentWindow"];

	// leave the project split view collapsed for now
	[splitView setPosition:0.0 ofDividerAtIndex:0];

	[[self window] makeKeyAndOrderFront:self];
}

- (id)windowWillReturnFieldEditor:(NSWindow *)window toObject:(id)anObject
{
	if ([anObject isKindOfClass:[NSTextField class]])
	{
		return [ExTextView defaultEditor];
	}
	return nil;
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

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
        lastDocument = [self currentDocument];
}

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
	[[self window] performClose:self];
}

- (BOOL)tabView:(NSTabView *)aTabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
	[tabView selectTabViewItem:tabViewItem];
	[[self window] performClose:[tabViewItem identifier]];
	return NO;
}

- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)aTabView
{
	/* Go through all tabs and reset all edit controllers delegates to self.
	 * Needed after a tab drag from another document window.
	 */

#if 0
	NSTabViewItem *item;
	for (item in [aTabView tabViewItems])
	{
		id oldDelegate = [[item identifier] delegate];
		INFO(@"old delegate for %@ = %@", [self displayName], oldDelegate);
		INFO(@"new delegate for %@ = %@", [self displayName], self);
		[[item identifier] setDelegate:self];
	}
#endif
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

- (IBAction)selectTab:(id)sender
{
	int tab = 0; // FIXME
	if (tab < [tabView numberOfTabViewItems])
		[tabView selectTabViewItem:[[[tabView delegate] representedTabViewItems] objectAtIndex:tab]];
}

- (IBAction)selectNextTab:(id)sender
{
	int num = [tabView numberOfTabViewItems];
	if (num <= 1)
		return;

	NSArray *tabs = [tabBar representedTabViewItems];
	int i;
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
	int num = [tabView numberOfTabViewItems];
	if (num <= 1)
		return;

	NSArray *tabs = [tabBar representedTabViewItems];
	int i;
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

- (ViTagStack *)sharedTagStack
{
	if (tagStack == nil)
		tagStack = [[ViTagStack alloc] init];
	return tagStack;
}

- (IBAction)toggleProjectDrawer:(id)sender
{
}

- (void)switchToLastFile
{
        [self selectDocument:lastDocument];
}

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
	return YES;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset
{
	return 70;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
{
	return 270;
}

- (BOOL)splitView:(NSSplitView *)splitView shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex
{
	return YES;
}

- (void)splitView:(id)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	NSRect newFrame = [sender frame];
	float dividerThickness = [sender dividerThickness];
	
	NSView *firstView = [[sender subviews] objectAtIndex:0];
	NSView *secondView = [[sender subviews] objectAtIndex:1];
	
	NSRect firstFrame = [firstView frame];
	NSRect secondFrame = [secondView frame];
	
	if (sender == splitView)
	{
		/* keep sidebar in constant width */
		secondFrame.size.width = newFrame.size.width - (firstFrame.size.width + dividerThickness);
		secondFrame.size.height = newFrame.size.height;
	}
	
	[secondView setFrame:secondFrame];
	[sender adjustSubviews];
}

@end

