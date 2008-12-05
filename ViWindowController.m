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
@synthesize selectedDocument;
@synthesize statusbar;

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
		symbolFilterCache = [[NSMutableDictionary alloc] init];
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
	[tabBar setPartnerView:splitView];
	[tabBar setShowAddTabButton:YES];
	[tabBar setAllowsDragBetweenWindows:NO];

	[[self window] setDelegate:self];
	[[self window] setFrameUsingName:@"MainDocumentWindow"];

	[splitView addSubview:symbolsView];
	[splitView setAutosaveName:@"ProjectSymbolSplitView"];

	isLoaded = YES;
	if (initialDocument)
	{
		[self addNewTab:initialDocument];
                lastDocument = initialDocument;
                initialDocument = nil;
	}

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

	[statusbar setFont:[NSFont userFixedPitchFontOfSize:12.0]];

	separatorCell = [[ViSeparatorCell alloc] init];
}

- (id)windowWillReturnFieldEditor:(NSWindow *)window toObject:(id)anObject
{
	if ([anObject isKindOfClass:[NSTextField class]] && anObject != symbolFilterField)
	{
		return [ExTextView defaultEditor];
	}
	return nil;
}

- (IBAction)addNewDocumentTab:(id)sender
{
	INFO(@"sender = %@", sender);
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

/* Called by a new ViDocument in its makeWindowControllers method.
 */
- (void)addNewTab:(ViDocument *)document
{
	if (!isLoaded)
	{
		/* Defer until NIB is loaded. */
		initialDocument = document;
		return;
	}

	INFO(@"add new tab for document %@", document);

	[tabBar addDocument:document];
	[self selectDocument:document];

	// update symbol table
	[documents addObject:document];
	[self filterSymbols:symbolFilterField];
	[document addObserver:self forKeyPath:@"symbols" options:0 context:NULL];
        NSInteger row = [symbolsOutline rowForItem:document];
        [symbolsOutline scrollRowToVisible:row];
        [symbolsOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
}

- (void)setMostRecentDocument:(ViDocument *)document view:(ViDocumentView *)docView
{
	mostRecentDocument = document;
	mostRecentView = docView;
}

- (void)selectDocument:(ViDocument *)aDocument
{
	INFO(@"select document %@", aDocument);

	if (!isLoaded || aDocument == nil)
		return;

	INFO(@"mostRecentDocument = %@", mostRecentDocument);
	NSView *superView = [[mostRecentView view] superview];
	INFO(@"mostRecentView = %@ (w/superview %@)", mostRecentView, superView);

	if (mostRecentDocument == aDocument)
		return;

	// create a new document view
	ViDocumentView *docView = [aDocument makeView];
	INFO(@"got docView %@", docView);

	// add the new view
	// if (![superView isKindOfClass:[NSSplitView class]])
	if (mostRecentView == nil)
	{
		NSRect frame = mostRecentView ? [[mostRecentView view] frame] : [documentView frame];
		frame.origin = NSMakePoint(0, 0);
		NSSplitView *split = [[NSSplitView alloc] initWithFrame:frame];
		[split setVertical:NO];
		[split setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		INFO(@"created split view %@, adding subview %@, frame %@", split, [docView view], NSStringFromRect(frame));
		[split addSubview:[docView view]];
		[split adjustSubviews];
		[documentView addSubview:split];
	}
	else
	{
		INFO(@"replacing document view %@ with %@", mostRecentView, docView);
		[superView replaceSubview:[mostRecentView view] with:[docView view]];
	}

	[[self document] removeWindowController:self];
	[aDocument addWindowController:self];
	[self setDocument:aDocument];

	lastDocument = [self selectedDocument];
	[self setSelectedDocument:aDocument];
	[tabBar didSelectDocument:aDocument];

	[[self window] makeFirstResponder:[docView textView]];
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

// - (BOOL)tabView:(NSTabView *)aTabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem
- (void)closeDocument:(ViDocument *)document
{
	INFO(@"close document %@", document);
	[document removeObserver:self forKeyPath:@"symbols"];
	[documents removeObject:document];
	[self filterSymbols:symbolFilterField];

	[[document view] removeFromSuperview];
	// FIXME: add another view

	[[self window] performClose:document];
	if (lastDocument == document)
		lastDocument = nil;
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

#if 0
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
#endif

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
	INFO(@"will close");
	if (currentWindowController == self)
		currentWindowController = nil;
	[windowControllers removeObject:self];
	[tabBar setDelegate:nil];
}

- (ViDocument *)currentDocument
{
	return [self selectedDocument];
}

#if 0
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
#endif

- (IBAction)selectNextTab:(id)sender
{
	NSArray *tabs = [tabBar representedDocuments];
	int num = [tabs count];
	if (num <= 1)
		return;

	int i;
	for (i = 0; i < num; i++)
	{
		if ([tabs objectAtIndex:i] == [self selectedDocument])
		{
			if (++i >= num)
				i = 0;
			[self selectDocument:[tabs objectAtIndex:i]];
			break;
		}
	}
}

- (IBAction)selectPreviousTab:(id)sender
{
	NSArray *tabs = [tabBar representedDocuments];
	int num = [tabs count];
	if (num <= 1)
		return;

	int i;
	for (i = 0; i < num; i++)
	{
		if ([tabs objectAtIndex:i] == [self selectedDocument])
		{
			if (--i < 0)
				i = num - 1;
			[self selectDocument:[tabs objectAtIndex:i]];
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

- (void)switchToLastFile
{
        [self selectDocument:lastDocument];
}

- (IBAction)splitViewHorizontally:(id)sender
{
	NSSplitView *split = [[mostRecentView view] superview];
	if ([split isKindOfClass:[NSSplitView class]])
	{
		ViDocumentView *dv = [mostRecentDocument makeView];
		[split addSubview:[dv view]];
		[split setPosition:100 ofDividerAtIndex:([[split subviews] count] - 2)];
		[split adjustSubviews];
	}
}

#pragma mark -
#pragma mark Split view delegate methods

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
	if (sender == splitView)
		return YES;
	return NO;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset
{
	if (sender == splitView)
	{
		if (offset == 0)
			return 100;
		NSRect frame = [sender frame];
		return frame.size.width - 300;
	}
	else
		return proposedMin;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
{
	if (sender == splitView)
	{
		if (offset == 0)
			return 300;
		return proposedMax - 100;
	}
	else
		return proposedMax;
}

- (BOOL)splitView:(NSSplitView *)sender shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex
{
	if (sender == splitView)
	{
		// collapse both side views, but not the edit view
		NSView *secondView = [[sender subviews] objectAtIndex:1];
		if (subview == secondView)
			return NO;
		return YES;
	}
	else
		return NO;
}

- (void)splitView:(id)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	if (sender != splitView)
		return;

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

- (NSRect)splitView:(NSSplitView *)sender additionalEffectiveRectOfDividerAtIndex:(NSInteger)dividerIndex
{
	if (sender != splitView)
		return NSMakeRect(0, 0, 0, 0);

	NSRect frame = [sender frame];
	NSRect resizeRect;
	if (dividerIndex == 0)
	{
		resizeRect = [projectResizeView frame];
	}
	else if (dividerIndex == 1)
	{
		resizeRect = [symbolsResizeView frame];
		resizeRect.origin = [sender convertPoint:resizeRect.origin fromView:symbolsResizeView];
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
	id item = [symbolsOutline itemAtRow:[symbolsOutline selectedRow]];
	if ([item isKindOfClass:[ViDocument class]])
	{
		[self selectDocument:item];
		[[self window] makeFirstResponder:[item textView]];
	}
	else
	{
		ViDocument *document = [symbolsOutline parentForItem:item];
		[self selectDocument:document];
		[document goToSymbol:item];

		// remember what symbol we selected from the filtered set
		NSString *filter = [symbolFilterField stringValue];
		[symbolFilterCache setObject:[item symbol] forKey:filter];
	}

	[symbolFilterField setStringValue:@""];
	[self filterSymbols:symbolFilterField];

        NSInteger row = [symbolsOutline rowForItem:item];
        [symbolsOutline scrollRowToVisible:row];
        [symbolsOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

	if (closeSymbolListAfterUse)
	{
		[self toggleSymbolList:self];
		closeSymbolListAfterUse = NO;
	}
}

- (IBAction)searchSymbol:(id)sender
{
	if ([splitView isSubviewCollapsed:symbolsView])
	{
		closeSymbolListAfterUse = YES;
		[self toggleSymbolList:nil];
	}
	[[self window] makeFirstResponder:symbolFilterField];
}

- (void)selectFirstMatchingSymbolForFilter:(NSString *)filter
{
	NSUInteger row;

	NSString *symbol = [symbolFilterCache objectForKey:filter];
	if (symbol)
	{
		// check if the cached symbol is available, then select it
		for (row = 0; row < [symbolsOutline numberOfRows]; row++)
		{
			id item = [symbolsOutline itemAtRow:row];
			if ([item isKindOfClass:[ViSymbol class]] && [[item symbol] isEqualToString:symbol])
			{
				[symbolsOutline scrollRowToVisible:row];
				[symbolsOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
				return;
			}
		}
	}

	// skip past all document entries, selecting the first symbol
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

	// make sure the current document is displayed first in the symbol list
	ViDocument *currentDocument = [self currentDocument];
	if (currentDocument)
	{
		[filteredDocuments removeObject:currentDocument];
		[filteredDocuments insertObject:currentDocument atIndex:0];
	}

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
	[self selectFirstMatchingSymbolForFilter:filter];
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
	else if (aSelector == @selector(cancelOperation:)) // escape
	{
		if (closeSymbolListAfterUse)
		{
			[self toggleSymbolList:self];
			closeSymbolListAfterUse = NO;
		}
		[symbolFilterField setStringValue:@""];
		[self filterSymbols:symbolFilterField];
		[[self window] makeFirstResponder:[mostRecentView view]];
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

