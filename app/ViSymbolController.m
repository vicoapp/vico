#import "ViSymbolController.h"
#import "MHTextIconCell.h"
#import "ViSeparatorCell.h"
#import "ViDocument.h"
#import "ViDocumentView.h"

@implementation ViSymbolController

- (id)init
{
	if ((self = [super init]) != nil) {
		symbolFilterCache = [NSMutableDictionary dictionary];
		width = 200.0;
	}
	return self;
}

- (void)awakeFromNib
{
	symbolView.keyManager = [[ViKeyManager alloc] initWithTarget:self
							      defaultMap:[ViMap symbolMap]];

	[symbolView setTarget:self];
	[symbolView setDoubleAction:@selector(gotoSymbolAction:)];
	[symbolView setAction:@selector(gotoSymbolAction:)];

	NSCell *cell = [[MHTextIconCell alloc] init];
	[[symbolView outlineTableColumn] setDataCell:cell];
	[cell setLineBreakMode:NSLineBreakByTruncatingTail];
	[cell setWraps:NO];

	separatorCell = [[ViSeparatorCell alloc] init];

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(firstResponderChanged:)
						     name:ViFirstResponderChangedNotification
						   object:nil];
}

- (void)firstResponderChanged:(NSNotification *)notification
{
	NSView *view = [notification object];
	if (view == symbolFilterField || view == [window fieldEditor:YES forObject:symbolFilterField])
		[self openSymbolListTemporarily:YES];
	else if ([view isKindOfClass:[NSView class]] && ![view isDescendantOf:symbolsView]) {
		[self closeSymbolList];
	}
}

- (void)didSelectDocument:(ViDocument *)document
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"autocollapse"] == YES)
		[symbolView collapseItem:nil collapseChildren:YES];
	[symbolView expandItem:document];
}

- (void)updateSelectedSymbolForLocation:(NSUInteger)aLocation
{
	NSArray *symbols = [[windowController currentDocument] symbols];
	id item = [windowController currentDocument];
	for (ViSymbol *symbol in symbols) {
		NSRange r = [symbol range];
		if (r.location > aLocation)
			break;
		item = symbol;
	}

	if (item) {
		NSUInteger row = [symbolView rowForItem:item];
		[symbolView scrollRowToVisible:row];
		[symbolView selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
			    byExtendingSelection:NO];
	}
}

- (BOOL)symbolListVisible
{
	NSView *view = [[splitView subviews] objectAtIndex:2];
	return ![splitView isSubviewCollapsed:view];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
	if (![keyPath isEqualToString:@"symbols"])
		return;

	dirty = YES;
	[reloadTimer invalidate];

	if ([self symbolListVisible])
		reloadTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
							       target:self
							     selector:@selector(symbolsUpdate:)
							     userInfo:nil
							      repeats:NO];
}

- (void)symbolsUpdate:(NSTimer *)aTimer
{
	dirty = NO;
	reloadTimer = nil;

	[self filterSymbols:symbolFilterField];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"autocollapse"] == YES) {
		[symbolView collapseItem:nil collapseChildren:YES];
		[symbolView expandItem:[windowController currentDocument]];
	}

	id<ViViewController> viewController = [windowController currentView];
	if ([viewController isKindOfClass:[ViDocumentView class]]) {
		ViDocumentView *docView = viewController;
		[self updateSelectedSymbolForLocation:[[docView textView] caret]];
	}
}

- (void)closeSymbolList
{
	if (closeSymbolListAfterUse) {
		NSRect frame = [splitView frame];
		[splitView setPosition:NSWidth(frame) ofDividerAtIndex:1];
		closeSymbolListAfterUse = NO;
	}
	if (hideToolbarAfterUse) {
		NSToolbar *toolbar = [window toolbar];
		[toolbar setVisible:NO];
		hideToolbarAfterUse = NO;
	}
}

- (void)resetSymbolList
{
	[symbolFilterField setStringValue:@""];
	[self filterSymbols:symbolFilterField];
}

- (void)cancelSymbolList
{
	[self resetSymbolList];
	[self closeSymbolList];
	[windowController focusEditor];
}

- (IBAction)gotoSymbolAction:(id)sender
{
	id item = [symbolView itemAtRow:[symbolView selectedRow]];

	// remember what symbol we selected from the filtered set
	NSString *filter = [symbolFilterField stringValue];
	if ([filter length] > 0 && [item isKindOfClass:[ViSymbol class]]) {
		[symbolFilterCache setObject:[item symbol] forKey:filter];
		[symbolFilterField setStringValue:@""];
	}

	if ([item isKindOfClass:[ViDocument class]])
		[windowController selectDocument:item];
	else
		[windowController gotoSymbol:item];

	[self cancelSymbolList];
}

- (BOOL)keyManager:(ViKeyManager *)keyManager
   evaluateCommand:(ViCommand *)command
{
	DEBUG(@"command is %@", command);
	id target;
	if ([symbolView respondsToSelector:command.action])
		target = symbolView;
	else if ([self respondsToSelector:command.action])
		target = self;
	else {
		[windowController message:@"Command not implemented."];
		return NO;
	}

	return (BOOL)[target performSelector:command.action withObject:command];
}

- (void)selectFirstMatchingSymbolForFilter:(NSString *)filter
{
	NSUInteger row;

	NSString *symbol = [symbolFilterCache objectForKey:filter];
	if (symbol) {
		// check if the cached symbol is available, then select it
		for (row = 0; row < [symbolView numberOfRows]; row++) {
			id item = [symbolView itemAtRow:row];
			if ([item isKindOfClass:[ViSymbol class]] &&
			    [[item symbol] isEqualToString:symbol]) {
				[symbolView scrollRowToVisible:row];
				[symbolView selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
					    byExtendingSelection:NO];
				return;
			}
		}
	}

	// skip past all document entries, selecting the first symbol
	for (row = 0; row < [symbolView numberOfRows]; row++) {
		id item = [symbolView itemAtRow:row];
		if ([item isKindOfClass:[ViSymbol class]]) {
			[symbolView scrollRowToVisible:row];
			[symbolView selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
				    byExtendingSelection:NO];
			break;
		}
	}
}

- (IBAction)filterSymbols:(id)sender
{
	NSString *filter = [sender stringValue];

	if ([filter length] == 0)
		isFiltered = NO;
	else
		isFiltered = YES;

	NSMutableString *pattern = [NSMutableString string];
	int i;
	for (i = 0; i < [filter length]; i++)
		[pattern appendFormat:@".*%C", [filter characterAtIndex:i]];
	[pattern appendString:@".*"];

	ViRegexp *rx = [[ViRegexp alloc] initWithString:pattern
					        options:ONIG_OPTION_IGNORECASE];

	filteredDocuments = [NSMutableArray arrayWithArray:windowController.documents];

	// make sure the current document is displayed first in the symbol list
	ViDocument *currentDocument = [windowController currentDocument];
	if (currentDocument) {
		[filteredDocuments removeObject:currentDocument];
		[filteredDocuments insertObject:currentDocument atIndex:0];
	}

	NSMutableArray *emptyDocuments = [NSMutableArray array];
	for (ViDocument *doc in filteredDocuments) {
		if (![doc respondsToSelector:@selector(filterSymbols:)] ||
		    [doc filterSymbols:rx] == 0)
			[emptyDocuments addObject:doc];
	}
	[filteredDocuments removeObjectsInArray:emptyDocuments];
	[symbolView reloadData];

	if ([filter length] > 0) {
		[symbolView expandItem:nil expandChildren:YES];
		[self selectFirstMatchingSymbolForFilter:filter];
	} else {
		[self didSelectDocument:[windowController currentDocument]];
	}
}

- (void)filterSymbols
{
	[self filterSymbols:symbolFilterField];
}

- (IBAction)toggleSymbolList:(id)sender
{
	NSView *view = [[splitView subviews] objectAtIndex:2];
	NSRect frame = [splitView frame];
	if ([splitView isSubviewCollapsed:view]) {
		if (dirty)
			[self symbolsUpdate:nil];
		[splitView setPosition:NSWidth(frame) - width ofDividerAtIndex:1];
	} else {
		width = [view bounds].size.width;
		[splitView setPosition:NSWidth(frame) ofDividerAtIndex:1];
	}
}

- (void)openSymbolListTemporarily:(BOOL)temporary
{
	NSView *view = [[splitView subviews] objectAtIndex:2];
	if ([splitView isSubviewCollapsed:view]) {
		closeSymbolListAfterUse = YES;
		[self toggleSymbolList:nil];
	}
}

- (IBAction)searchSymbol:(id)sender
{
	NSToolbar *toolbar = [window toolbar];
	if (![[toolbar items] containsObject:searchToolbarItem]) {
		NSBeep();
		return;
	}
	hideToolbarAfterUse = ![toolbar isVisible];
	[toolbar setVisible:YES];
	if (![[toolbar visibleItems] containsObject:searchToolbarItem]) {
		if (hideToolbarAfterUse) {
			[toolbar setVisible:NO];
			hideToolbarAfterUse = NO;
		}
		NSBeep();
		return;
	}
	[window makeFirstResponder:symbolFilterField];
}

- (IBAction)focusSymbols:(id)sender
{
	NSView *view = [[splitView subviews] objectAtIndex:2];
	if ([splitView isSubviewCollapsed:view]) {
		closeSymbolListAfterUse = YES;
		[self toggleSymbolList:nil];
	}

	[window makeFirstResponder:symbolView];
}

#pragma mark -
#pragma mark Symbol filter key handling

- (BOOL)control:(NSControl *)sender
       textView:(NSTextView *)textView
doCommandBySelector:(SEL)aSelector
{
	if (sender != symbolFilterField)
		return NO;

	if (aSelector == @selector(insertNewline:)) { // enter
		[self gotoSymbolAction:self];
		return YES;
	} else if (aSelector == @selector(moveUp:)) { // up arrow
		NSInteger row = [symbolView selectedRow];
		if (row > 0)
			[symbolView selectRowIndexes:[NSIndexSet indexSetWithIndex:row - 1]
				    byExtendingSelection:NO];
		return YES;
	} else if (aSelector == @selector(moveDown:)) { // down arrow
		NSInteger row = [symbolView selectedRow];
		if (row + 1 < [symbolView numberOfRows])
			[symbolView selectRowIndexes:[NSIndexSet indexSetWithIndex:row + 1]
				    byExtendingSelection:NO];
		return YES;
	} else if (aSelector == @selector(cancelOperation:)) { // escape
		if (isFiltered) {
			[window makeFirstResponder:symbolView];
			/* make sure something is selected */
			if ([symbolView selectedRow] == -1)
				[symbolView selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
				      byExtendingSelection:NO];
		} else
			[self cancelSymbolList];
		return YES;
	}

	return NO;
}

#pragma mark -
#pragma mark Command Actions

- (BOOL)find:(ViCommand *)command
{
	[window makeFirstResponder:symbolFilterField];
	return YES;
}

- (BOOL)switch_open:(ViCommand *)command
{
	id symbol = [symbolView itemAtRow:[symbolView selectedRow]];

	ViDocument *doc;
	if ([symbol isKindOfClass:[ViDocument class]]) {
		doc = symbol;
		symbol = nil;
	} else {
		doc = [(ViSymbol *)symbol document];
	}

	// remember what symbol we selected from the filtered set
	NSString *filter = [symbolFilterField stringValue];
	if (symbol && [filter length] > 0) {
		[symbolFilterCache setObject:symbol forKey:filter];
		[symbolFilterField setStringValue:@""];
	}

	windowController.jumping = YES; /* XXX: need better API! */
	if ([windowController currentDocument] != doc)
		[windowController switchToDocument:doc];
	windowController.jumping = NO;
	if (symbol)
		[windowController gotoSymbol:symbol inView:[windowController currentView]];

	[self closeSymbolList];
	[windowController focusEditor];
	return YES;
}

- (void)splitVertically:(BOOL)isVertical andGotoSymbol:(id)symbol
{
	ViDocument *doc;
	if ([symbol isKindOfClass:[ViDocument class]]) {
		doc = symbol;
		symbol = nil;
	} else
		doc = [(ViSymbol *)symbol document];

	// remember what symbol we selected from the filtered set
	NSString *filter = [symbolFilterField stringValue];
	if (symbol && [filter length] > 0) {
		[symbolFilterCache setObject:symbol forKey:filter];
		[symbolFilterField setStringValue:@""];
	}

	windowController.jumping = YES; /* XXX: need better API! */
	[windowController splitVertically:isVertical
				  andOpen:nil
		       orSwitchToDocument:doc];
	windowController.jumping = NO;

	if (symbol)
		[windowController gotoSymbol:symbol inView:[windowController currentView]];

	[self closeSymbolList];
}

- (BOOL)split_open:(ViCommand *)command
{
	id item = [symbolView itemAtRow:[symbolView selectedRow]];
	[self splitVertically:NO andGotoSymbol:item];
	return YES;
}

- (BOOL)vsplit_open:(ViCommand *)command
{
	id item = [symbolView itemAtRow:[symbolView selectedRow]];
	[self splitVertically:YES andGotoSymbol:item];
	return YES;
}

- (BOOL)tab_open:(ViCommand *)command
{
	id symbol = [symbolView itemAtRow:[symbolView selectedRow]];

	ViDocument *doc;
	if ([symbol isKindOfClass:[ViDocument class]]) {
		doc = symbol;
		symbol = nil;
	} else {
		doc = [(ViSymbol *)symbol document];
	}

	// remember what symbol we selected from the filtered set
	NSString *filter = [symbolFilterField stringValue];
	if (symbol && [filter length] > 0) {
		[symbolFilterCache setObject:symbol forKey:filter];
		[symbolFilterField setStringValue:@""];
	}

	windowController.jumping = YES; /* XXX: need better API! */
	ViDocumentView *docView = [windowController createTabForDocument:doc];
	windowController.jumping = NO;
	if (symbol)
		[windowController gotoSymbol:symbol inView:docView];

	[self closeSymbolList];
	return YES;
}

- (BOOL)open:(ViCommand *)command
{
	[self gotoSymbolAction:nil];
	return YES;
}

- (BOOL)cancel_or_reset:(ViCommand *)command
{
	if (isFiltered)
		[self resetSymbolList];
	else
		[self cancelSymbolList];
	return YES;
}

- (BOOL)cancel:(ViCommand *)command
{
	[self cancelSymbolList];
	return YES;
}

#pragma mark -
#pragma mark Symbol Outline View Data Source

- (id)outlineView:(NSOutlineView *)outlineView
            child:(NSInteger)anIndex
           ofItem:(id)item
{
	if (item == nil)
		return [filteredDocuments objectAtIndex:anIndex];
	return [[(ViDocument *)item filteredSymbols] objectAtIndex:anIndex];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView
   isItemExpandable:(id)item
{
	if ([item isKindOfClass:[ViDocument class]])
		return [[(ViDocument *)item filteredSymbols] count] > 0 ? YES : NO;
	return NO;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView
  numberOfChildrenOfItem:(id)item
{
	if (item == nil)
		return [filteredDocuments count];

	if ([item isKindOfClass:[ViDocument class]])
		return [[(ViDocument *)item filteredSymbols] count];

	return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView
objectValueForTableColumn:(NSTableColumn *)tableColumn
           byItem:(id)item
{
	return [item displayName];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView
        isGroupItem:(id)item
{
	if ([item isKindOfClass:[ViDocument class]])
		return YES;
	return NO;
}

- (BOOL)isSeparatorItem:(id)item
{
	if ([item isKindOfClass:[ViSymbol class]] &&
	    [[(ViSymbol *)item symbol] isEqualToString:@"-"])
		return YES;
	return NO;
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
	if ([self isSeparatorItem:item])
		return 9;
	if ([self outlineView:outlineView isGroupItem:item])
		return 20;
	return 15;
}

- (NSCell *)outlineView:(NSOutlineView *)outlineView
 dataCellForTableColumn:(NSTableColumn *)tableColumn
                   item:(id)item
{
	NSCell *cell;
	if ([self isSeparatorItem:item])
		cell = separatorCell;
	else {
		cell  = [tableColumn dataCellForRow:[symbolView rowForItem:item]];

		if ([item respondsToSelector:@selector(image)])
			[cell setImage:[item image]];
		else
			[cell setImage:nil];
	}

	if (![item isKindOfClass:[ViDocument class]])
		[cell setFont:[NSFont systemFontOfSize:11.0]];
	else
		[cell setFont:[NSFont systemFontOfSize:13.0]];

	return cell;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
	return ![self isSeparatorItem:item];
}

@end
