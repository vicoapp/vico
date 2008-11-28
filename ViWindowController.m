#import "ViWindowController.h"
#import <PSMTabBarControl/PSMTabBarControl.h>
#import "ViDocument.h"
#import "ExTextView.h"
#import "ProjectDelegate.h"
#import "ViSymbol.h"
#import "ViSeparatorCell.h"
#import "ViSymbolSearchField.h"

static NSMutableArray		*windowControllers = nil;
static NSWindowController	*currentWindowController = nil;

@implementation ViWindowController

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

	[splitView addSubview:symbolsView];
	[splitView setAutosaveName:@"ProjectSymbolSplitView"];

	NSCell *cell = [(NSTableColumn *)[[projectOutline tableColumns] objectAtIndex:0] dataCell];
	// [cell setFont:[NSFont systemFontOfSize:11.0]];
	// [projectOutline setRowHeight:15.0];
	[cell setLineBreakMode:NSLineBreakByTruncatingTail];
	[cell setWraps:NO];

	[[self window] makeKeyAndOrderFront:self];

	[symbolsOutline setTarget:self];
	[symbolsOutline setDoubleAction:@selector(goToSymbol:)];
	[symbolsOutline setAction:@selector(goToSymbol:)];
	cell = [(NSTableColumn *)[[symbolsOutline tableColumns] objectAtIndex:0] dataCell];
	[cell setLineBreakMode:NSLineBreakByTruncatingTail];
	[cell setWraps:NO];

	separatorCell = [[ViSeparatorCell alloc] init];
}

- (id)windowWillReturnFieldEditor:(NSWindow *)window toObject:(id)anObject
{
	if ([anObject isKindOfClass:[NSTextField class]])
	{
		if (anObject == symbolFilterField)
		{
			if (symbolFieldEditor == nil)
			{
				symbolFieldEditor = [[NSTextView alloc] initWithFrame:NSMakeRect(0,0,0,0)];
				[symbolFieldEditor setFieldEditor:YES];
				[symbolFieldEditor setDelegate:self];
			}
			return symbolFieldEditor;
		}
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
	{
		[self filterSymbols:symbolFilterField];
		if ([self currentDocument] == object)
			[symbolsOutline expandItem:object];
	}
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
	[self filterSymbols:symbolFilterField];
	[document addObserver:self forKeyPath:@"symbols" options:0 context:NULL];
        NSInteger row = [symbolsOutline rowForItem:document];
        [symbolsOutline scrollRowToVisible:row];
        [symbolsOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
}

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
        lastDocument = [self currentDocument];
        ViDocument *document = [tabViewItem identifier];

        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"autocollapse"] == YES)
		[symbolsOutline collapseItem:nil collapseChildren:YES];
        [symbolsOutline expandItem:document];
        
        // unless current selection is a symbol in the current document, select the document itself
        id selectedItem = [symbolsOutline itemAtRow:[symbolsOutline selectedRow]];
        if (selectedItem != document && [symbolsOutline parentForItem:selectedItem] != document)
        {
		NSInteger row = [symbolsOutline rowForItem:[tabViewItem identifier]];
		[symbolsOutline scrollRowToVisible:row];
		[symbolsOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        }
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
	[self filterSymbols:symbolFilterField];

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
	NSRect frame = [sender frame];
	return frame.size.width - 300;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
{
	if (offset == 0)
		return 300;
	return proposedMax - 100;
}

- (BOOL)splitView:(NSSplitView *)aSplitView shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex
{
	// collapse both side views, but not the edit view
	NSView *secondView = [[aSplitView subviews] objectAtIndex:1];
	if (subview == secondView)
		return NO;
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

	NSInteger firstWidth = firstFrame.size.width;
	if ([splitView isSubviewCollapsed:firstView])
		firstWidth = 0;

	NSInteger thirdWidth = thirdFrame.size.width;
	if ([splitView isSubviewCollapsed:thirdView])
		thirdWidth = 0;

	/* keep sidebar in constant width */
	secondFrame.size.width = newFrame.size.width - (firstWidth + thirdWidth + dividerThickness);
	secondFrame.size.height = newFrame.size.height;

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

- (IBAction)toggleSymbolList:(id)sender
{
	NSRect frame = [splitView frame];
	if ([splitView isSubviewCollapsed:symbolsView])
		[splitView setPosition:NSWidth(frame) - 200 ofDividerAtIndex:1];
	else
		[splitView setPosition:NSWidth(frame) ofDividerAtIndex:1];
}

- (void)goToSymbol:(id)sender
{
	INFO(@"selected row = %i", [symbolsOutline selectedRow]);

	id item = [symbolsOutline itemAtRow:[symbolsOutline selectedRow]];
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
	[symbolFilterField setStringValue:@""];
	[self filterSymbols:symbolFilterField];

        NSInteger row = [symbolsOutline rowForItem:item];
        [symbolsOutline scrollRowToVisible:row];
        [symbolsOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
}

- (IBAction)searchSymbol:(id)sender
{
	if ([splitView isSubviewCollapsed:symbolsView])
		[self toggleSymbolList:nil];
	[[self window] makeFirstResponder:symbolFilterField];
}

- (void)selectFirstMatchingSymbol
{
	NSUInteger row;
	for (row = 0; row < [symbolsOutline numberOfRows]; row++)
	{
		id item = [symbolsOutline itemAtRow:row];
		if ([item isKindOfClass:[ViSymbol class]])
		{
			[symbolsOutline scrollRowToVisible:row];
			[symbolsOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
			break;
		}
	}
}

- (IBAction)filterSymbols:(id)sender
{
	NSString *filter = [sender stringValue];

	NSMutableString *pattern = [NSMutableString string];
	int i;
	for (i = 0; i < [filter length]; i++)
	{
		[pattern appendFormat:@".*%C", [filter characterAtIndex:i]];
	}
	[pattern appendString:@".*"];

	ViRegexp *rx = [ViRegexp regularExpressionWithString:pattern options:ONIG_OPTION_IGNORECASE];

	filteredDocuments = [[NSMutableArray alloc] initWithArray:documents];
	ViDocument *doc;
	NSMutableArray *emptyDocuments = [[NSMutableArray alloc] init];
	for (doc in filteredDocuments)
	{
		if ([doc filterSymbols:rx] == 0)
			[emptyDocuments addObject:doc];
	}
	[filteredDocuments removeObjectsInArray:emptyDocuments];
	[symbolsOutline reloadData];
	[symbolsOutline expandItem:nil expandChildren:YES];
	[self selectFirstMatchingSymbol];
}

- (BOOL)searchField:(NSSearchField *)aSearchField doCommandBySelector:(SEL)aSelector
{
	INFO(@"selector = %s", aSelector);

	if (aSelector == @selector(insertNewline:)) // enter
	{
		[self goToSymbol:self];
		return YES;
	}
	else if (aSelector == @selector(moveUp:)) // up arrow
	{
		NSInteger row = [symbolsOutline selectedRow];
		if (row > 0)
		{
			[symbolsOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:row - 1] byExtendingSelection:NO];
		}
		return YES;
	}
	else if (aSelector == @selector(moveDown:)) // down arrow
	{
		NSInteger row = [symbolsOutline selectedRow];
		if (row + 1 < [symbolsOutline numberOfRows])
		{
			[symbolsOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:row + 1] byExtendingSelection:NO];
		}
		return YES;
	}

	return NO;
}

#pragma mark -
#pragma mark Symbol Outline View Data Source

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)anIndex ofItem:(id)item
{
	if (item == nil)
		return [filteredDocuments objectAtIndex:anIndex];
	return [[(ViDocument *)item filteredSymbols] objectAtIndex:anIndex];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	if ([item isKindOfClass:[ViDocument class]])
	{
		return [[(ViDocument *)item filteredSymbols] count] > 0 ? YES : NO;
	}
	return NO;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if (item == nil)
		return [filteredDocuments count];

	if ([item isKindOfClass:[ViDocument class]])
		return [[(ViDocument *)item filteredSymbols] count];

	return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	return [item displayName];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
	if ([item isKindOfClass:[ViDocument class]])
		return YES;
	return NO;
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
	if ([item isKindOfClass:[ViDocument class]])
		return 20;
	return 15;
}


- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	NSCell *cell;
	if ([item isKindOfClass:[ViSymbol class]] && [[(ViSymbol *)item symbol] isEqualToString:@"-"])
	{
		cell = separatorCell;
	}
	else
		cell  = [tableColumn dataCellForRow:[symbolsOutline rowForItem:item]];
	if (![item isKindOfClass:[ViDocument class]])
		[cell setFont:[NSFont systemFontOfSize:11.0]];
	else
		[cell setFont:[NSFont systemFontOfSize:13.0]];
	return cell;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
	if ([item isKindOfClass:[ViSymbol class]] && [[(ViSymbol *)item symbol] isEqualToString:@"-"])
		return NO;
	return YES;
}

@end

