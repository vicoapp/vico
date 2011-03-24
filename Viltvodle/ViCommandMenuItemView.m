#import "ViCommandMenuItemView.h"
#import "NSScanner-additions.h"
#include "logging.h"

@implementation ViCommandMenuItemView : NSView

@synthesize command, title;

/* Expands <special> to a nice visual representation.
 *
 * Format of the <special> keys are:
 *   <^@r> => control-command-r (apple style)
 *   <^@R> => shift-control-command-r (apple style)
 *   <c-r> => control-r (vim style)
 *   <C-R> => control-r (vim style)
 *   <Esc> => escape (vim style)
 *   <space> => space (vim style)
 *   ...
 */
- (NSString *)expandSpecialKeys:(NSString *)string
{
	NSMutableString *s = [NSMutableString string];
	NSScanner *scan = [NSScanner scannerWithString:string];
	unichar ch;
	while ([scan scanCharacter:&ch]) {
		if (ch == '\\') {
			/* Escaped character. */
			if ([scan scanCharacter:&ch]) {
				[s appendString:[NSString stringWithFormat:@"%C", ch]];
			} else {
				/* trailing backslash? treat as literal */
				[s appendString:@"\\"];
			}
		} else if (ch == '<') {
			NSString *special = nil;
			if ([scan scanUpToUnescapedCharacter:'>' intoString:&special] &&
			    [scan scanString:@">" intoString:nil]) {
				DEBUG(@"parsing special key <%@>", special);
				if ([[special lowercaseString] isEqualToString:@"cr"])
					[s appendString:[NSString stringWithFormat:@"%C", 0x21A9]];
				else if ([[special lowercaseString] isEqualToString:@"esc"])
					[s appendString:[NSString stringWithFormat:@"%C", 0x238B]];
				else if ([[special lowercaseString] hasPrefix:@"c-"]) {
					/* control-key */
					[s appendString:[NSString stringWithFormat:@"%C", 0x2303]];
					[s appendString:[[special substringFromIndex:2] uppercaseString]];
					if (![scan isAtEnd]) {
						/* Add a thin space after a control-key */
						[s appendString:[NSString stringWithFormat:@"%C", 0x2009]];
					}
				}
			} else {
				/* "<" without a ">", treat as literal */
				if (special)
					[s appendString:special];
				[s appendString:@"<"];
			}
		} else
			[s appendString:[NSString stringWithFormat:@"%C", ch]];
	}
	return s;
}

- (void)setCommand:(NSString *)aCommand
{
	NSSize oldSize = [command sizeWithAttributes:attributes];
	command = [self expandSpecialKeys:aCommand];
	commandSize = [command sizeWithAttributes:attributes];

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

- (id)initWithTitle:(NSString *)aTitle command:(NSString *)aCommand
{
	double w, h;

	command = [self expandSpecialKeys:aCommand];

	attributes = [NSMutableDictionary dictionaryWithObject:[NSFont menuBarFontOfSize:0] forKey:NSFontAttributeName];
	titleSize = [aTitle sizeWithAttributes:attributes];
	commandSize = [command sizeWithAttributes:attributes];

	h = titleSize.height + 1;
	w = 20 + titleSize.width + 30 + commandSize.width + 15;

	self = [super initWithFrame:NSMakeRect(0, 0, w, h)];
	if (self) {
		title = aTitle;
		[self setAutoresizingMask:NSViewWidthSizable];
	}
	return self;
}

- (id)initWithTitle:(NSString *)aTitle tabTrigger:(NSString *)aTabTrigger
{
	return [self initWithTitle:aTitle command:[aTabTrigger stringByAppendingFormat:@"%C", 0x21E5]];
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
	NSPoint p = NSMakePoint(b.size.width - commandSize.width - 15, 1);
	NSRect bg = NSMakeRect(p.x - 4, p.y, commandSize.width + 8, commandSize.height);
	if (!enabled)
		[[NSColor colorWithCalibratedRed:(CGFloat)0xE5/0xFF green:(CGFloat)0xE5/0xFF blue:(CGFloat)0xE5/0xFF alpha:1.0] set];
	else if (highlighted)
		[[NSColor colorWithCalibratedRed:(CGFloat)0x2B/0xFF green:(CGFloat)0x41/0xFF blue:(CGFloat)0xD3/0xFF alpha:1.0] set];
	else
		[[NSColor colorWithCalibratedRed:(CGFloat)0xD5/0xFF green:(CGFloat)0xD5/0xFF blue:(CGFloat)0xD5/0xFF alpha:1.0] set];
	[[NSBezierPath bezierPathWithRoundedRect:bg xRadius:6 yRadius:6] fill];

	[command drawAtPoint:p withAttributes:attributes];
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
