#import <Quartz/Quartz.h>

#import "ViSymbolController.h"
#import "MHTextIconCell.h"
#import "ViSeparatorCell.h"
#import "ViDocument.h"
#import "ViDocumentView.h"
#import "ViBgView.h"
#import "ViWindow.h"

@implementation ViSymbolController

- (id)init
{
	if ((self = [super init]) != nil) {
		_symbolFilterCache = [[NSMutableDictionary alloc] init];
		_width = 200.0;
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_separatorCell release];
	[_symbolFilterCache release];
	[super dealloc];
}

- (void)awakeFromNib
{
	symbolView.keyManager = [ViKeyManager keyManagerWithTarget:self
							defaultMap:[ViMap symbolMap]];

	[symbolView setTarget:self];
	[symbolView setDoubleAction:@selector(gotoSymbolAction:)];
	[symbolView setAction:@selector(gotoSymbolAction:)];

	NSCell *cell = [[[MHTextIconCell alloc] init] autorelease];
	[[symbolView outlineTableColumn] setDataCell:cell];
	[cell setLineBreakMode:NSLineBreakByTruncatingTail];
	[cell setWraps:NO];

	_separatorCell = [[ViSeparatorCell alloc] init];

	symbolsView.backgroundColor = [symbolView backgroundColor];

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(firstResponderChanged:)
						     name:ViFirstResponderChangedNotification
						   object:nil];
}

- (void)firstResponderChanged:(NSNotification *)notification
{
	NSView *view = [notification object];
	DEBUG(@"view = %@ (%@ or %@?)", view, symbolFilterField, altSymbolFilterField);
	if (view == symbolFilterField || view == altSymbolFilterField)
		[self openSymbolListTemporarily:YES];
	else if ([view isKindOfClass:[NSView class]] && ![view isDescendantOf:symbolsView]) {
		if ([view isKindOfClass:[NSTextView class]] && [(NSTextView *)view isFieldEditor])
			return;
		if (_closeSymbolListAfterUse) {
			[self closeSymbolListAndFocusEditor:NO];
			_closeSymbolListAfterUse = NO;
		}
		[self hideAltFilterField];
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
	for (ViMark *symbol in symbols) {
		NSRange r = symbol.range;
		if (r.location > aLocation)
			break;
		if (![self isSeparatorItem:symbol])
			item = symbol;
	}

	if (item) {
		NSUInteger row = [symbolView rowForItem:item];
		[symbolView scrollRowToVisible:row];
		[symbolView selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
			    byExtendingSelection:NO];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
	if (![keyPath isEqualToString:@"symbols"])
		return;

	_dirty = YES;
	[_reloadTimer invalidate];
	[_reloadTimer release];

	if ([self symbolListIsOpen])
		_reloadTimer = [[NSTimer scheduledTimerWithTimeInterval:0.1
								 target:self
							       selector:@selector(symbolsUpdate:)
							       userInfo:nil
								repeats:NO] retain];
	else
		_reloadTimer = nil;
}

- (void)symbolsUpdate:(NSTimer *)aTimer
{
	_dirty = NO;

	[_reloadTimer release];
	_reloadTimer = nil;

	_symbolUpdateDuringFiltering = _isFiltered;
	id selectedItem = nil;
	if (_symbolUpdateDuringFiltering)
		selectedItem = [symbolView itemAtRow:[symbolView selectedRow]];

	[self filterSymbols];

	if (_symbolUpdateDuringFiltering) {
		NSInteger row = [symbolView rowForItem:selectedItem];
		if (row != -1LL) {
			[symbolView scrollRowToVisible:row];
			[symbolView selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
				byExtendingSelection:NO];
		}
	} else {
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
	_symbolUpdateDuringFiltering = NO;
}

- (void)closeSymbolListAndFocusEditor:(BOOL)focusEditor
{
	_width = [symbolsView frame].size.width;
	NSRect frame = [splitView frame];
	[splitView setPosition:NSWidth(frame) ofDividerAtIndex:1];
	if (focusEditor)
		[windowController focusEditor];
}

- (void)resetSymbolList
{
	[symbolFilterField setStringValue:@""];
	[altSymbolFilterField setStringValue:@""];
	[self hideAltFilterField];
	[self filterSymbols:symbolFilterField];
}

- (void)cancelSymbolList
{
	[windowController focusEditorDelayed];
	if (_closeSymbolListAfterUse) {
		[self closeSymbolListAndFocusEditor:NO];
		_closeSymbolListAfterUse = NO;
	}
	[self resetSymbolList];
}

- (IBAction)gotoSymbolAction:(id)sender
{
	id item = [symbolView itemAtRow:[symbolView selectedRow]];

	// remember what symbol we selected from the filtered set
	NSString *filter;
	if ([altSymbolFilterField isHidden])
		filter = [altSymbolFilterField stringValue];
	else
		filter = [symbolFilterField stringValue];
	if ([filter length] > 0 && [item isKindOfClass:[ViMark class]]) {
		[_symbolFilterCache setObject:[item title] forKey:filter];
		[symbolFilterField setStringValue:@""];
		[altSymbolFilterField setStringValue:@""];
	}

	if ([item isKindOfClass:[ViDocument class]])
		[windowController selectDocument:item];
	else
		[windowController gotoMark:item];

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

	return [command performWithTarget:target];
}

- (void)selectFirstMatchingSymbolForFilter:(NSString *)filter
{
	NSUInteger row;

	NSString *symbol = [_symbolFilterCache objectForKey:filter];
	if (symbol) {
		// check if the cached symbol is available, then select it
		for (row = 0; row < [symbolView numberOfRows]; row++) {
			id item = [symbolView itemAtRow:row];
			if ([item isKindOfClass:[ViMark class]] &&
			    [[item title] isEqualToString:symbol]) {
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
		if ([item isKindOfClass:[ViMark class]]) {
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
		_isFiltered = NO;
	else
		_isFiltered = YES;

	NSMutableString *pattern = [NSMutableString string];
	int i;
	for (i = 0; i < [filter length]; i++)
		[pattern appendFormat:@".*%C", [filter characterAtIndex:i]];
	[pattern appendString:@".*"];

	ViRegexp *rx = [ViRegexp regexpWithString:pattern
					  options:ONIG_OPTION_IGNORECASE];

	[_filteredDocuments release];
	_filteredDocuments = [[NSMutableArray alloc] initWithArray:[windowController.documents allObjects]];

	// make sure the current document is displayed first in the symbol list
	ViDocument *currentDocument = [windowController currentDocument];
	if (currentDocument) {
		[_filteredDocuments removeObject:currentDocument];
		[_filteredDocuments insertObject:currentDocument atIndex:0];
	}

	NSMutableArray *emptyDocuments = [NSMutableArray array];
	for (ViDocument *doc in _filteredDocuments) {
		if (![doc respondsToSelector:@selector(filterSymbols:)] ||
		    [doc filterSymbols:rx] == 0)
			[emptyDocuments addObject:doc];
	}
	[_filteredDocuments removeObjectsInArray:emptyDocuments];
	[symbolView reloadData];

	if (!_symbolUpdateDuringFiltering) {
		if (_isFiltered) {
			[symbolView expandItem:nil expandChildren:YES];
			[self selectFirstMatchingSymbolForFilter:filter];
		} else {
			[self didSelectDocument:[windowController currentDocument]];
		}
	}
}

- (void)filterSymbols
{
	if ([altSymbolFilterField isHidden])
		[self filterSymbols:symbolFilterField];
	else
		[self filterSymbols:altSymbolFilterField];
}

- (BOOL)symbolListIsOpen
{
	return ![splitView isSubviewCollapsed:symbolsView];
}

- (void)openSymbolListTemporarily:(BOOL)temporarily
{
	if (![self symbolListIsOpen]) {
		if (temporarily)
			_closeSymbolListAfterUse = YES;
		NSRect frame = [splitView frame];
		[splitView setPosition:frame.size.width - _width ofDividerAtIndex:1];
		if (_dirty)
			[self symbolsUpdate:nil];
	}
}

- (IBAction)toggleSymbolList:(id)sender
{
	if ([self symbolListIsOpen])
		[self closeSymbolListAndFocusEditor:NO];
	else
		[self openSymbolListTemporarily:NO];
}

#if 0

- (void)showAltFilterField
{
	if ([altSymbolFilterField isHidden]) {
		_isHidingAltFilterField = NO;
		[NSAnimationContext beginGrouping];
		[[NSAnimationContext currentContext] setDuration:0.1];

		NSRect symbolsFrame = [symbolsView frame];

		NSRect frame = [scrollView frame];
		frame.size.height = symbolsFrame.size.height - 23 - 24;
		[[scrollView animator] setFrame:frame];

		[altSymbolFilterField setFrame:NSMakeRect(1, symbolsFrame.size.height - 1, symbolsFrame.size.width - 2, 0)];
		[altSymbolFilterField setHidden:NO];
		[[altSymbolFilterField animator] setFrame:NSMakeRect(1, symbolsFrame.size.height - 23, symbolsFrame.size.width - 2, 22)];

		CAAnimation *animation = [altSymbolFilterField animationForKey:@"frameOrigin"];
		animation.delegate = self;

		[NSAnimationContext endGrouping];
	}
}

- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)flag
{
	if (flag) {
		if (_isHidingAltFilterField)
			[altSymbolFilterField setHidden:YES];
		else {
			NSRect symbolsFrame = [symbolsView frame];
			[altSymbolFilterField setFrame:NSMakeRect(1, symbolsFrame.size.height - 23, symbolsFrame.size.width - 2, 22)];
			[[altSymbolFilterField cell] calcDrawInfo:[altSymbolFilterField frame]];
		}
	}
}

- (void)hideAltFilterField
{
	if (![altSymbolFilterField isHidden]) {
		_isHidingAltFilterField = YES;
		[NSAnimationContext beginGrouping];
		[[NSAnimationContext currentContext] setDuration:0.1];

		NSRect symbolsFrame = [symbolsView frame];

		NSRect frame = [scrollView frame];
		frame.size.height = symbolsFrame.size.height - 23;
		[[scrollView animator] setFrame:frame];

		NSRect altFrame = [altSymbolFilterField frame];
		altFrame.size.height = 2;
		altFrame.origin = NSMakePoint(1, symbolsFrame.size.height - 1);
		[[altSymbolFilterField animator] setFrame:altFrame];

		CAAnimation *animation = [altSymbolFilterField animationForKey:@"frameOrigin"];
		animation.delegate = self;

		[NSAnimationContext endGrouping];
	}
}

#else

- (void)showAltFilterField
{
	if ([altSymbolFilterField isHidden]) {
		NSRect symbolsFrame = [symbolsView frame];
		NSRect frame = [scrollView frame];
		frame.size.height = symbolsFrame.size.height - 23 - 22 - 3;
		[scrollView setFrame:frame];
                [altSymbolFilterField setHidden:NO];
	}
}

- (void)hideAltFilterField
{
	if (![altSymbolFilterField isHidden]) {
		NSRect symbolsFrame = [symbolsView frame];
		NSRect frame = [scrollView frame];
		frame.size.height = symbolsFrame.size.height - 23;
		[scrollView setFrame:frame];
                [altSymbolFilterField setHidden:YES];
	}
}

#endif

- (IBAction)searchSymbol:(id)sender
{
	[self openSymbolListTemporarily:YES];
	NSToolbar *toolbar = [window toolbar];
	if (![(ViWindow *)window isFullScreen] && [toolbar isVisible] && [[toolbar items] containsObject:searchToolbarItem]) {
		[window makeFirstResponder:symbolFilterField];
	} else {
		[self showAltFilterField];
		[window makeFirstResponder:altSymbolFilterField];
	}
}

- (IBAction)focusSymbols:(id)sender
{
	[self openSymbolListTemporarily:YES];
	[window makeFirstResponder:symbolView];
}

#pragma mark -
#pragma mark Symbol filter key handling

- (BOOL)control:(NSControl *)sender
       textView:(NSTextView *)textView
doCommandBySelector:(SEL)aSelector
{
	if (sender != symbolFilterField && sender != altSymbolFilterField)
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
		if (_isFiltered) {
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
	[self searchSymbol:nil];
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
		doc = [(ViMark *)symbol document];
	}

	// remember what symbol we selected from the filtered set
	NSString *filter;
	if ([altSymbolFilterField isHidden])
		filter = [symbolFilterField stringValue];
	else
		filter = [altSymbolFilterField stringValue];
	if (symbol && [filter length] > 0) {
		[_symbolFilterCache setObject:symbol forKey:filter];
		[symbolFilterField setStringValue:@""];
		[altSymbolFilterField setStringValue:@""];
	}

	windowController.jumping = YES; /* XXX: need better API! */
	if ([windowController currentDocument] != doc)
		[windowController switchToDocument:doc];
	windowController.jumping = NO;
	if (symbol)
		[windowController gotoMark:symbol];

	[self cancelSymbolList];
	return YES;
}

- (void)splitVertically:(BOOL)isVertical andGotoSymbol:(id)symbol
{
	ViDocument *doc;
	if ([symbol isKindOfClass:[ViDocument class]]) {
		doc = symbol;
		symbol = nil;
	} else
		doc = [(ViMark *)symbol document];

	// remember what symbol we selected from the filtered set
	NSString *filter;
	if ([altSymbolFilterField isHidden])
		filter = [symbolFilterField stringValue];
	else
		filter = [altSymbolFilterField stringValue];
	if (symbol && [filter length] > 0) {
		[_symbolFilterCache setObject:symbol forKey:filter];
		[symbolFilterField setStringValue:@""];
		[altSymbolFilterField setStringValue:@""];
	}

	windowController.jumping = YES; /* XXX: need better API! */
	[windowController splitVertically:isVertical
				  andOpen:nil
		       orSwitchToDocument:doc];
	windowController.jumping = NO;

	if (symbol)
		[windowController gotoMark:symbol];

	[self cancelSymbolList];
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
		doc = [(ViMark *)symbol document];
	}

	// remember what symbol we selected from the filtered set
	NSString *filter;
	if ([altSymbolFilterField isHidden])
		filter = [symbolFilterField stringValue];
	else
		filter = [altSymbolFilterField stringValue];
	if (symbol && [filter length] > 0) {
		[_symbolFilterCache setObject:symbol forKey:filter];
		[symbolFilterField setStringValue:@""];
		[altSymbolFilterField setStringValue:@""];
	}

	windowController.jumping = YES; /* XXX: need better API! */
	ViDocumentView *docView = [windowController createTabForDocument:doc];
	windowController.jumping = NO;
	if (symbol)
		[windowController gotoMark:symbol];

	[self cancelSymbolList];
	return YES;
}

- (BOOL)open:(ViCommand *)command
{
	[self gotoSymbolAction:nil];
	return YES;
}

- (BOOL)cancel_or_reset:(ViCommand *)command
{
	if (_isFiltered)
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
		return [_filteredDocuments objectAtIndex:anIndex];
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
		return [_filteredDocuments count];

	if ([item isKindOfClass:[ViDocument class]])
		return [[(ViDocument *)item filteredSymbols] count];

	return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView
objectValueForTableColumn:(NSTableColumn *)tableColumn
           byItem:(id)item
{
	return [item title];
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
	if ([item isKindOfClass:[ViMark class]] &&
	    [[(ViMark *)item title] isEqualToString:@"-"])
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
		cell = _separatorCell;
	else {
		cell  = [tableColumn dataCellForRow:[symbolView rowForItem:item]];

		if ([item respondsToSelector:@selector(icon)])
			[cell setImage:[item icon]];
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
