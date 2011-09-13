#import "ViOutlineView.h"
#import "NSEvent-keyAdditions.h"
#import "ViError.h"
#import "NSView-additions.h"
#include "logging.h"

@implementation ViOutlineView

@synthesize keyManager, strictIndentation;

- (void)awakeFromNib
{
	if (keyManager == nil)
		keyManager = [[ViKeyManager alloc] initWithTarget:self
						       defaultMap:[ViMap mapWithName:@"tableNavigationMap"]];
}

- (BOOL)keyManager:(ViKeyManager *)keyManager
   evaluateCommand:(ViCommand *)command
{
	id target = [self targetForSelector:command.action];
	DEBUG(@"got target %@ for command %@", target, command);
	if (target == nil)
		return NO;
	return (BOOL)[target performSelector:command.action withObject:command];
}

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
