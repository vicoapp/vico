#import "ViOutlineView.h"
#import "NSEvent-keyAdditions.h"
#import "ViError.h"
#import "NSView-additions.h"
#include "logging.h"

@implementation ViOutlineView

@synthesize keyManager = _keyManager;
@synthesize strictIndentation = _strictIndentation;

- (void)awakeFromNib
{
	if (_keyManager == nil)
		[self setKeyManager:[ViKeyManager keyManagerWithTarget:self
							    defaultMap:[ViMap mapWithName:@"tableNavigationMap"]]];
}

- (BOOL)keyManager:(ViKeyManager *)keyManager
   evaluateCommand:(ViCommand *)command
{
	return [self performCommand:command];
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
	if ([[self window] firstResponder] != self)
		return NO;
	return [_keyManager performKeyEquivalent:theEvent];
}

- (void)keyDown:(NSEvent *)theEvent
{
	[_keyManager keyDown:theEvent];
}

#pragma mark -

- (void)swipeWithEvent:(NSEvent *)event
{
	DEBUG(@"got swipe event %@", event);
	[_keyManager.parser reset];
	if ([event deltaX] > 0)
		[_keyManager runAsMacro:@"<ctrl-o>"];
	else if ([event deltaX] < 0)
		[_keyManager runAsMacro:@"<ctrl-i>"];
}

#pragma mark -

- (NSRect)frameOfCellAtColumn:(NSInteger)columnIndex row:(NSInteger)rowIndex
{
	NSRect frame = [super frameOfCellAtColumn:columnIndex row:rowIndex];
	if (_strictIndentation) {
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
	if (_strictIndentation) {
		NSInteger level = [self levelForRow:rowIndex];
		frame.origin.x = 4 + level * [self indentationPerLevel];
	}
	return frame;
}

@end
