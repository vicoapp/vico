#import "NSOutlineView-vimotions.h"

@implementation NSOutlineView (vimotions)

/* [count]l */
- (BOOL)move_right:(ViCommand *)command
{
	NSInteger row = [self selectedRow];
	id item = [self itemAtRow:row];
	if (item && [[self dataSource] outlineView:self isItemExpandable:item])
		[self expandItem:item];
	return YES;
}

/* [count]h */
- (BOOL)move_left:(ViCommand *)command
{
	NSInteger row = [self selectedRow];
	id item = [self itemAtRow:row];
	if (item == nil)
		return NO;
	if ([[self dataSource] outlineView:self isItemExpandable:item] &&
	    [self isItemExpanded:item])
		[self collapseItem:item];
	else {
		id parent = [self parentForItem:item];
		if (parent) {
			row = [self rowForItem:parent];
			[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
			      byExtendingSelection:NO];
			[self scrollRowToVisible:row];
		}
	}
	return YES;
}

@end
