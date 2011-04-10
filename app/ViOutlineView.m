#import "ViOutlineView.h"
#import "NSEvent-keyAdditions.h"
#import "ViError.h"
#include "logging.h"

@implementation ViOutlineView

@synthesize keyManager, lastSelectedRow;

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
	if ([[self window] firstResponder] != self)
		return NO;
	return [keyManager performKeyEquivalent:theEvent];
}

- (void)keyDown:(NSEvent *)theEvent
{
	[keyManager keyDown:theEvent];
}

#pragma mark -
#pragma mark Command Actions

/* [count]j */
- (BOOL)move_down:(ViCommand *)command
{
	int c = IMAX(1, command.count);
	NSInteger row = [self selectedRow];
	if (row == -1)
		row = 0;
	else
		row = IMIN([self numberOfRows] - 1, row + c);
	[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
	      byExtendingSelection:NO];
	[self scrollRowToVisible:row];
	lastSelectedRow = row;
	return YES;
}

/* [count]k */
- (BOOL)move_up:(ViCommand *)command
{
	int c = IMAX(1, command.count);
	NSInteger row = [self selectedRow];
	if (row == -1)
		row = 0;
	else
		row = IMAX(0, row - c);
	[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
	      byExtendingSelection:NO];
	[self scrollRowToVisible:row];
	lastSelectedRow = row;
	return YES;
}

/* [count]l */
- (BOOL)move_right:(ViCommand *)command
{
	NSInteger row = [self selectedRow];
	id item = [self itemAtRow:row];
	if (item && [[self delegate] outlineView:self isItemExpandable:item]) {
		[self expandItem:item];
		lastSelectedRow = row;
	}
	return YES;
}

/* [count]h */
- (BOOL)move_left:(ViCommand *)command
{
	NSInteger row = [self selectedRow];
	id item = [self itemAtRow:row];
	if (item == nil)
		return NO;
	if ([[self delegate] outlineView:self isItemExpandable:item] &&
	    [self isItemExpanded:item])
		[self collapseItem:item];
	else {
		id parent = [self parentForItem:item];
		if (parent) {
			row = [self rowForItem:parent];
			[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
			      byExtendingSelection:NO];
			[self scrollRowToVisible:row];
			lastSelectedRow = row;
		}
	}
	return YES;
}

/* [count]H */
- (BOOL)move_high:(ViCommand *)command
{
	NSRect bounds = [[self enclosingScrollView] documentVisibleRect];
	NSInteger row = [self rowAtPoint:bounds.origin];
	[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
	      byExtendingSelection:NO];
	[self scrollRowToVisible:row];
	lastSelectedRow = row;
	return YES;
}

/* [count]M */
- (BOOL)move_middle:(ViCommand *)command
{
	NSRect bounds = [[self enclosingScrollView] documentVisibleRect];
	NSInteger firstRow = [self rowAtPoint:bounds.origin];
	NSInteger lastRow = [self rowAtPoint:
	    NSMakePoint(bounds.origin.x, bounds.origin.y + bounds.size.height)];
	if (lastRow == -1)
		lastRow = [self numberOfRows] - 1;
	NSInteger row = firstRow + (lastRow - firstRow) / 2;
	[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	[self scrollRowToVisible:row];
	lastSelectedRow = row;
	return YES;
}

/* [count]L */
- (BOOL)move_low:(ViCommand *)command
{
	NSRect bounds = [[self enclosingScrollView] documentVisibleRect];
	NSInteger row = [self rowAtPoint:
	    NSMakePoint(bounds.origin.x, bounds.origin.y + bounds.size.height)];
	if (row == -1)
		row = [self numberOfRows] - 1;
	[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
	      byExtendingSelection:NO];
	[self scrollRowToVisible:row];
	lastSelectedRow = row;
	return YES;
}

/* <home> */
- (BOOL)move_home:(ViCommand *)command
{
	[self selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
	      byExtendingSelection:NO];
	[self scrollRowToVisible:0];
	lastSelectedRow = 0;
	return YES;
}

/* <end> */
- (BOOL)move_end:(ViCommand *)command
{
	NSInteger row = [self numberOfRows] - 1;
	[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
	      byExtendingSelection:NO];
	[self scrollRowToVisible:row];
	lastSelectedRow = row;
	return YES;
}

/* ctrl-y */
- (BOOL)scroll_up_by_line:(ViCommand *)command
{
	NSClipView *clipView = [[self enclosingScrollView] contentView];
	NSRect bounds = [[self enclosingScrollView] documentVisibleRect];
	NSInteger firstRow = [self rowAtPoint:bounds.origin];
	if (firstRow == 0) {
		/* First row already visible. */
		if (bounds.origin.y > 0) {
			[clipView scrollToPoint:NSMakePoint(0, 0)];
			[[self enclosingScrollView] reflectScrolledClipView:clipView];
		}
		return NO;
	}

	NSInteger lastRow = [self rowAtPoint:
	    NSMakePoint(bounds.origin.x, bounds.origin.y + bounds.size.height)];
	if (lastRow == -1)
		lastRow = [self numberOfRows];
	lastRow--;

	NSRect r = [self rectOfRow:lastRow];
	r.origin.y -= bounds.size.height;
	[clipView scrollToPoint:r.origin];
	[[self enclosingScrollView] reflectScrolledClipView:clipView];

	if ([self selectedRow] >= lastRow) {
		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:lastRow - 1]
		      byExtendingSelection:NO];
		lastSelectedRow = lastRow - 1;
	}

	return YES;
}

/* ctrl-e */
- (BOOL)scroll_down_by_line:(ViCommand *)command
{
	NSClipView *clipView = [[self enclosingScrollView] contentView];
	NSRect bounds = [[self enclosingScrollView] documentVisibleRect];
	NSInteger lastRow = [self rowAtPoint:
	    NSMakePoint(bounds.origin.x, bounds.origin.y + bounds.size.height)];
	if (lastRow == -1) {
		/* Last row already visible. */
		return NO;
	}

	NSInteger firstRow = [self rowAtPoint:bounds.origin] + 1;

	NSRect r = [self rectOfRow:firstRow];
	[clipView scrollToPoint:r.origin];
	[[self enclosingScrollView] reflectScrolledClipView:clipView];

	if ([self selectedRow] < firstRow) {
		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:firstRow]
		      byExtendingSelection:NO];
		lastSelectedRow = firstRow;
	}

	return YES;
}

- (BOOL)backward_screen:(ViCommand *)command
{
	NSRect bounds = [[self enclosingScrollView] documentVisibleRect];
	NSInteger firstRow = [self rowAtPoint:bounds.origin];
	NSInteger lastRow = [self rowAtPoint:
	    NSMakePoint(bounds.origin.x, bounds.origin.y + bounds.size.height)];
	NSInteger maxRow = [self numberOfRows] - 1;
	if (lastRow == -1)
		lastRow = maxRow;
	NSInteger screenRows = lastRow - firstRow;

	NSInteger currentRow = [self selectedRow];
	if (currentRow == -1)
		currentRow = 0;
	NSInteger row = IMAX(0, currentRow - screenRows);

	[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
	      byExtendingSelection:NO];
	[self scrollRowToVisible:row];
	lastSelectedRow = row;
	return YES;
}

- (BOOL)forward_screen:(ViCommand *)command
{
	NSRect bounds = [[self enclosingScrollView] documentVisibleRect];
	NSInteger firstRow = [self rowAtPoint:bounds.origin];
	NSInteger lastRow = [self rowAtPoint:
	    NSMakePoint(bounds.origin.x, bounds.origin.y + bounds.size.height)];
	NSInteger maxRow = [self numberOfRows] - 1;
	if (lastRow == -1)
		lastRow = maxRow;
	NSInteger screenRows = lastRow - firstRow;

	NSInteger currentRow = [self selectedRow];
	if (currentRow == -1)
		currentRow = 0;
	NSInteger row = IMIN(maxRow, currentRow + screenRows);

	[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
	      byExtendingSelection:NO];
	[self scrollRowToVisible:row];
	lastSelectedRow = row;
	return YES;
}

/* syntax: [count]G */
- (BOOL)goto_line:(ViCommand *)command
{
	NSInteger row = -1;
	BOOL defaultToEOF = [command.mapping.parameter intValue];
	if (command.count > 0)
		row = IMIN(command.count, [self numberOfRows]) - 1;
	else if (defaultToEOF)
		row = [self numberOfRows] - 1;
	else
		row = 0;

	[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
	      byExtendingSelection:NO];
	[self scrollRowToVisible:row];
	lastSelectedRow = row;
	return YES;
}

@end
