#import "ViCommandMenuItemView.h"
#import "NSScanner-additions.h"
#import "NSString-additions.h"
#import "NSObject+SPInvocationGrabbing.h"
#import "NSEvent-keyAdditions.h"
#include "logging.h"

@implementation ViCommandMenuItemView : NSView

@synthesize command, title;

- (void)setCommand:(NSString *)aCommand
{
	NSSize oldSize = [commandTitle sizeWithAttributes:attributes];
	command = aCommand;
	commandTitle = [command visualKeyString];
	commandSize = [commandTitle sizeWithAttributes:attributes];

	double dw = commandSize.width - oldSize.width;
	double dh = commandSize.height - oldSize.height;

	NSRect frame = [self frame];
	frame.size.width += dw;
	frame.size.height += dh;
	[self setFrame:frame];
}

- (void)setTabTrigger:(NSString *)aTabTrigger
{
	[self setCommand:[aTabTrigger stringByAppendingFormat:@"%C", 0x21E5]];
}

- (void)setTitle:(NSString *)aTitle
{
	NSSize oldSize = [title sizeWithAttributes:attributes];
	title = aTitle;
	titleSize = [title sizeWithAttributes:attributes];

	double dw = titleSize.width - oldSize.width;
	double dh = titleSize.height - oldSize.height;

	NSRect frame = [self frame];
	frame.size.width += dw;
	frame.size.height += dh;
	[self setFrame:frame];
}

- (id)initWithTitle:(NSString *)aTitle command:(NSString *)aCommand font:(NSFont *)aFont
{
	double w, h;

	command = aCommand;
	commandTitle = [command visualKeyString];

	attributes = [NSMutableDictionary dictionaryWithObject:aFont
							forKey:NSFontAttributeName];
	titleSize = [aTitle sizeWithAttributes:attributes];
	commandSize = [commandTitle sizeWithAttributes:attributes];
	disabledColor = [NSColor colorWithCalibratedRed:(CGFloat)0xE5/0xFF
						  green:(CGFloat)0xE5/0xFF
						   blue:(CGFloat)0xE5/0xFF
						  alpha:1.0];
	highlightColor = [NSColor colorWithCalibratedRed:(CGFloat)0x2B/0xFF
						   green:(CGFloat)0x41/0xFF
						    blue:(CGFloat)0xD3/0xFF
						   alpha:1.0];
	normalColor = [NSColor colorWithCalibratedRed:(CGFloat)0xD5/0xFF
						green:(CGFloat)0xD5/0xFF
						 blue:(CGFloat)0xD5/0xFF
						alpha:1.0];

	h = titleSize.height + 1;
	w = 20 + titleSize.width + 30 + commandSize.width + 15;

	self = [super initWithFrame:NSMakeRect(0, 0, w, h)];
	if (self) {
		title = aTitle;
		[self setAutoresizingMask:NSViewWidthSizable];
	}
	return self;
}

- (id)initWithTitle:(NSString *)aTitle tabTrigger:(NSString *)aTabTrigger font:(NSFont *)aFont
{
	return [self initWithTitle:aTitle
			   command:[aTabTrigger stringByAppendingFormat:@"%C", 0x21E5]
			      font:aFont];
}

- (void)drawRect:(NSRect)dirtyRect
{
	BOOL enabled = [[self enclosingMenuItem] isEnabled];
	BOOL highlighted = [[self enclosingMenuItem] isHighlighted];

	if (enabled && highlighted) {
		[[NSColor selectedMenuItemColor] set];
		[[NSBezierPath bezierPathWithRect:[self bounds]] fill];
	}

	if (!enabled)
		[attributes setObject:[NSColor disabledControlTextColor]
			       forKey:NSForegroundColorAttributeName];
	else if (highlighted)
		[attributes setObject:[NSColor selectedMenuItemTextColor]
			       forKey:NSForegroundColorAttributeName];
	else
		[attributes setObject:[NSColor controlTextColor]
			       forKey:NSForegroundColorAttributeName];
	[title drawAtPoint:NSMakePoint(21, 1) withAttributes:attributes];

	NSRect b = [self bounds];
	NSPoint p = NSMakePoint(b.size.width - commandSize.width - 15, 1);
	NSRect bg = NSMakeRect(p.x - 4, p.y, commandSize.width + 8, commandSize.height);
	if (!enabled)
		[disabledColor set];
	else if (highlighted)
		[highlightColor set];
	else
		[normalColor set];
	[[NSBezierPath bezierPathWithRoundedRect:bg xRadius:6 yRadius:6] fill];

	[commandTitle drawAtPoint:p withAttributes:attributes];
}

- (void)performAction
{
	NSMenuItem *item = [self enclosingMenuItem];
	if (![item isEnabled])
		return;

	NSMenu *menu = [item menu];
	NSInteger itemIndex = [menu indexOfItem:item];

	[menu cancelTracking];
	[[menu nextRunloop] performActionForItemAtIndex:itemIndex];
	[[menu nextRunloop] update];

	// XXX: Hack to force the menuitem to loose the highlight
	[[menu nextRunloop] removeItemAtIndex:itemIndex];
	[[menu nextRunloop] insertItem:item atIndex:itemIndex];
}

- (void)mouseUp:(NSEvent *)event
{
	[self performAction];
}

- (void)keyDown:(NSEvent *)event
{
	NSUInteger keyCode = [event normalizedKeyCode];
	if (keyCode == 0xa || keyCode == 0xd || keyCode == ' ')
		[self performAction];
	else
		[super keyDown:event];
}

@end
