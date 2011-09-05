#import "ViOutlineView.h"
#import "NSEvent-keyAdditions.h"
#import "ViError.h"
#include "logging.h"

@implementation ViOutlineView

@synthesize keyManager, strictIndentation;

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

- (void)swipeWithEvent:(NSEvent *)event
{
	DEBUG(@"got swipe event %@", event);
	[keyManager.parser reset];
	if ([event deltaX] > 0)
		[keyManager runAsMacro:@"<ctrl-o>"];
	else if ([event deltaX] < 0)
		[keyManager runAsMacro:@"<ctrl-i>"];
}

#pragma mark -

- (NSRect)frameOfCellAtColumn:(NSInteger)columnIndex row:(NSInteger)rowIndex
{
	NSRect frame = [super frameOfCellAtColumn:columnIndex row:rowIndex];
	if (strictIndentation) {
		NSInteger level = [self levelForRow:rowIndex];
		NSInteger diff = 15 + level * [self indentationPerLevel] - frame.origin.x;
		frame.origin.x += diff;
		frame.size.width -= diff;
	}
	return frame;
}

- (NSRect)frameOfOutlineCellAtRow:(NSInteger)rowIndex
{
	NSRect frame = [super frameOfOutlineCellAtRow:rowIndex];
	if (strictIndentation) {
		NSInteger level = [self levelForRow:rowIndex];
		frame.origin.x = 4 + level * [self indentationPerLevel];
	}
	return frame;
}

@end
