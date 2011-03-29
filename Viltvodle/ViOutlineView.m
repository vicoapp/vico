#import "ViOutlineView.h"
#import "NSEvent-keyAdditions.h"
#include "logging.h"

@implementation ViOutlineView

- (void)awakeFromNib
{
	parser = [[ViParser alloc] initWithDefaultMap:[ViMap explorerMap]]; // XXX: ...or symbolMap?
}

- (void)keyDown:(NSEvent *)theEvent
{
	ViCommand *command = [parser pushKey:[theEvent normalizedKeyCode]
				       scope:nil
				     timeout:nil
				       error:nil];
	if (command)
		if ([[self delegate] respondsToSelector:@selector(outlineView:evaluateCommand:)])
			[[self delegate] outlineView:self evaluateCommand:command];
}

@end
