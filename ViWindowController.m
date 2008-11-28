#import "ViWindowController.h"
#import <PSMTabBarControl/PSMTabBarControl.h>
#import "ViDocument.h"
#import "ExTextView.h"
#import "ProjectDelegate.h"
#import "ViSymbol.h"

static NSMutableArray		*windowControllers = nil;
static NSWindowController	*currentWindowController = nil;

@implementation ViWindowController

@synthesize filteredSymbols;
@synthesize documents;

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
		documents = [[NSMutableArray alloc] init];
	}

	return self;
}

- (IBAction)saveProject:(id)sender
{
	[projectDelegate saveProject:sender];
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
                initialDocument = nil;
	}
	[[self window] setDelegate:self];
	[[self window] setFrameUsingName:@"MainDocumentWindow"];

	NSCell *cell = [(NSTableColumn *)[[projectOutline tableColumns] objectAtIndex:0] dataCell];
	[cell setFont:[NSFont systemFontOfSize:11.0]];
	[projectOutline setRowHeight:15.0];
	[cell setLineBreakMode:NSLineBreakByTruncatingTail];
	[cell setWraps:NO];

	[[self window] makeKeyAndOrderFront:self];

	[splitView addSubview:symbolsView];

	[symbolsOutline setTarget:self];
	[symbolsOutline setDoubleAction:@selector(goToSymbol:)];
	[symbolsOutline setAction:@selector(goToSymbol:)];
	cell = [(NSTableColumn *)[[symbolsOutline tableColumns] objectAtIndex:0] dataCell];
	[cell setFont:[NSFont systemFontOfSize:11.0]];
	[symbolsOutline setRowHeight:15.0];
	[cell setLineBreakMode:NSLineBreakByTruncatingTail];
	[cell setWraps:NO];
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

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"symbols"])
		[symbolsOutline reloadData];
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

	[documents addObject:document];
	[symbolsOutline reloadData];

	[document addObserver:self forKeyPath:@"symbols" options:0 context:NULL];

#if 0
	NSTreeNode *node;
	for (node in [symbolsController arrangedObjects])
	{
		if ([node representedObject] == document)
		{
			INFO(@"expanding node %@", node);
			[symbolsOutline expandItem:node];
		}
	}
#endif
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

- (BOOL)tabView:(NSTabView *)aTabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
	ViDocument *document = [tabViewItem identifier];

	[document removeObserver:self forKeyPath:@"symbols"];
	[documents removeObject:document];
	[symbolsOutline reloadData];

	[tabView selectTabViewItem:tabViewItem];
	[[self window] performClose:document];
	if (lastDocument == document)
		lastDocument = nil;
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

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
	NSString *projName = [projectDelegate projectName];
	if (projName)
		return [NSString stringWithFormat:@"%@ - %@", displayName, projName];
	return displayName;
}

#pragma mark -
#pragma mark Split view delegate methods

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
	if (offset == 0)
		return 100;
	return proposedMin;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
{
	if (offset == 0)
		return 270;
	return proposedMax;
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
	NSView *thirdView = nil;
	int nsubviews = [[sender subviews] count];
	if (nsubviews == 3)
		thirdView = [[sender subviews] objectAtIndex:2];

	NSRect firstFrame = [firstView frame];
	NSRect secondFrame = [secondView frame];
	NSRect thirdFrame = [thirdView frame];

	if (sender == splitView)
	{
		/* keep sidebar in constant width */
		secondFrame.size.width = newFrame.size.width - (firstFrame.size.width + dividerThickness);
		secondFrame.size.height = newFrame.size.height;
	}

	[secondView setFrame:secondFrame];
	[sender adjustSubviews];
}

- (NSRect)splitView:(NSSplitView *)aSplitView additionalEffectiveRectOfDividerAtIndex:(NSInteger)dividerIndex
{
	NSRect frame = [aSplitView frame];
	NSRect resizeRect;
	if (dividerIndex == 0)
	{
		resizeRect = [projectResizeView frame];
	}
	else if (dividerIndex == 1)
	{
		resizeRect = [symbolsResizeView frame];
		resizeRect.origin = [splitView convertPoint:resizeRect.origin fromView:symbolsResizeView];
	}
	else
		return NSMakeRect(0, 0, 0, 0);

	resizeRect.origin.y = NSHeight(frame) - NSHeight(resizeRect);
	return resizeRect;
}

#pragma mark -
#pragma mark Symbol List

- (void)goToSymbol:(id)sender
{
	INFO(@"sender = %@", sender);
	id item = [symbolsOutline itemAtRow:[symbolsOutline clickedRow]];
	if ([item isKindOfClass:[ViDocument class]])
	{
		[self selectDocument:item];
	}
	else
	{
		ViDocument *document = [symbolsOutline parentForItem:item];
		[self selectDocument:document];
		[document goToSymbol:item];
	}
#if 0
	[symbolFilterField setStringValue:@""];
	[self filterSymbols:symbolFilterField];
#endif
}

- (IBAction)filterSymbols:(id)sender
{
#if 0
	NSString *filter = [sender stringValue];

	NSMutableString *pattern = [NSMutableString string];
	int i;
	for (i = 0; i < [filter length]; i++)
	{
		[pattern appendFormat:@".*%C", [filter characterAtIndex:i]];
	}
	[pattern appendString:@".*"];

	ViRegexp *rx = [ViRegexp regularExpressionWithString:pattern options:ONIG_OPTION_IGNORECASE];

	NSMutableArray *fs = [[NSMutableArray alloc] initWithCapacity:[symbols count]];
	ViSymbol *s;
	for (s in symbols)
	{
		if ([rx matchInString:[s symbol]])
		{
			[fs addObject:s];
		}
	}

	[fs sortUsingSelector:@selector(sortOnLocation:)];
	[self setFilteredSymbols:fs];
#endif
}

#pragma mark -
#pragma mark Symbol Outline View Data Source

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
	if (item == nil)
		return [documents objectAtIndex:index];
	return [[(ViDocument *)item symbols] objectAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	if ([item isKindOfClass:[ViDocument class]])
	{
		return [[(ViDocument *)item symbols] count] > 0 ? YES : NO;
	}
	return NO;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if (item == nil)
		return [documents count];

	if ([item isKindOfClass:[ViDocument class]])
		return [[(ViDocument *)item symbols] count];

	return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	return [item displayName];
}

@end

