/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "NSTableView-vimotions.h"
#import "ViCommon.h"

@implementation NSTableView (vimotions)

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
	return YES;
}

/* <home> */
- (BOOL)move_home:(ViCommand *)command
{
	[self selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
	      byExtendingSelection:NO];
	[self scrollRowToVisible:0];
	return YES;
}

/* <end> */
- (BOOL)move_end:(ViCommand *)command
{
	NSInteger row = [self numberOfRows] - 1;
	[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
	      byExtendingSelection:NO];
	[self scrollRowToVisible:row];
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
	return YES;
}

/* syntax: <cr> */
- (BOOL)double_action:(ViCommand *)command
{
	SEL doubleAction = [self doubleAction];
	if (doubleAction == NULL)
		return NO;
	
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

	[[self target] performSelector:doubleAction withObject:self];
	
#pragma clang diagnostic pop
	
	return YES;
}

@end
