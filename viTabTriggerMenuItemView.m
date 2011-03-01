#import "ViTabTriggerMenuItemView.h"
#include "logging.h"

@implementation ViTabTriggerMenuItemView : NSView

- (id)initWithTitle:(NSString *)aTitle tabTrigger:(NSString *)aTabTrigger
{
	double w, h;

	tabTrigger = [aTabTrigger stringByAppendingFormat:@"%C", 0x21E5];

	attributes = [NSMutableDictionary dictionaryWithObject:[NSFont menuFontOfSize:0] forKey:NSFontAttributeName];
	titleSize = [aTitle sizeWithAttributes:attributes];
	triggerSize = [tabTrigger sizeWithAttributes:attributes];

	h = titleSize.height + 1;
	w = 20 + titleSize.width + 30 + triggerSize.width + 10;

	self = [super initWithFrame:NSMakeRect(0, 0, w, h)];
	if (self) {
		title = aTitle;
		[self setAutoresizingMask:NSViewWidthSizable];
	}
	return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
	BOOL enabled =  [[self enclosingMenuItem] isEnabled];
	BOOL highlighted = [[self enclosingMenuItem] isHighlighted];

	if (enabled && highlighted) {
		[[NSColor selectedMenuItemColor] set];
		[[NSBezierPath bezierPathWithRect:[self bounds]] fill];
	}

	if (!enabled)
		[attributes setObject:[NSColor disabledControlTextColor] forKey:NSForegroundColorAttributeName];
	else if (highlighted)
		[attributes setObject:[NSColor selectedMenuItemTextColor] forKey:NSForegroundColorAttributeName];
	else
		[attributes setObject:[NSColor controlTextColor] forKey:NSForegroundColorAttributeName];
	[title drawAtPoint:NSMakePoint(21, 1) withAttributes:attributes];

	NSRect b = [self bounds];
	NSPoint p = NSMakePoint(b.size.width - triggerSize.width - 10, 1);
	NSRect bg = NSMakeRect(p.x - 4, p.y, triggerSize.width + 8, triggerSize.height);
	if (!enabled)
		[[NSColor colorWithCalibratedRed:(CGFloat)0xE5/0xFF green:(CGFloat)0xE5/0xFF blue:(CGFloat)0xE5/0xFF alpha:1.0] set];
	else if (highlighted)
		[[NSColor colorWithCalibratedRed:(CGFloat)0x2B/0xFF green:(CGFloat)0x41/0xFF blue:(CGFloat)0xD3/0xFF alpha:1.0] set];
	else
		[[NSColor colorWithCalibratedRed:(CGFloat)0xD5/0xFF green:(CGFloat)0xD5/0xFF blue:(CGFloat)0xD5/0xFF alpha:1.0] set];
	[[NSBezierPath bezierPathWithRoundedRect:bg xRadius:4 yRadius:4] fill];

	[tabTrigger drawAtPoint:p withAttributes:attributes];
}

- (void)mouseUp:(NSEvent*)event
{
	NSMenuItem *item = [self enclosingMenuItem];
	if (![item isEnabled])
		return;

	NSMenu *menu = [item menu];
	// XXX: that (id) is not a nice cast!
	[menu performSelector:@selector(performActionForItemAtIndex:) withObject:(id)[menu indexOfItem:item] afterDelay:0.0];
	[menu cancelTracking];
}

@end
