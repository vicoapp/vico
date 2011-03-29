#import "ViWebView.h"
#import "ViCommon.h"
#import "ViWindowController.h"
#import "NSEvent-keyAdditions.h"
#include "logging.h"

@implementation ViWebView

@synthesize environment, parser;

- (void)swipeWithEvent:(NSEvent *)event
{
	BOOL rc = NO, keep_message = NO;

	DEBUG(@"got swipe event %@", event);

	if ([event deltaX] > 0)
		rc = [self goBack];
	else if ([event deltaX] < 0)
		rc = [self goForward];

	if (rc == YES && !keep_message)
		[environment message:@""]; // erase any previous message
}

- (BOOL)evaluateCommand:(ViCommand *)command
{
	if (![self respondsToSelector:command.action] ||
	    (command.motion && ![self respondsToSelector:command.motion.action])) {
		[environment message:@"Command not implemented."];
		return NO;
	}

	DEBUG(@"perform command %@", command);
	BOOL ok = (NSUInteger)[self performSelector:command.action
					 withObject:command];

	if (ok)	// erase any previous message
		[environment message:@""];

	return ok;
}

- (void)switch_tab:(int)arg
{
	if (arg-- == 0)
		arg = 9;
        [[[self window] windowController] selectTabAtIndex:arg];
}

- (void)keyDown:(NSEvent *)theEvent
{
#if 0
	/* Special handling of command-[0-9] to switch tabs. */
	if (flags == NSCommandKeyMask && charcode >= '0' && charcode <= '9') {
		[self switch_tab:charcode - '0'];
		return;
	}

	if ((flags & ~NSNumericPadKeyMask) != 0) {
		DEBUG(@"unhandled key equivalent %C/0x%04X", charcode, flags);
		return;
	}
#endif

	ViCommand *command = [parser pushKey:[theEvent normalizedKeyCode]
				       scope:nil
				     timeout:nil
				       error:nil];
	if (command)
		[self evaluateCommand:command];
}

- (BOOL)window_left:(ViCommand *)command
{
	return [[[self window] windowController] selectViewAtPosition:ViViewLeft relativeTo:self];
}

- (BOOL)window_down:(ViCommand *)command
{
	return [[[self window] windowController] selectViewAtPosition:ViViewDown relativeTo:self];
}

- (BOOL)window_up:(ViCommand *)command
{
	return [[[self window] windowController] selectViewAtPosition:ViViewUp relativeTo:self];
}

- (BOOL)window_right:(ViCommand *)command
{
	return [[[self window] windowController] selectViewAtPosition:ViViewRight relativeTo:self];
}

- (BOOL)window_close:(ViCommand *)command
{
	return [environment ex_close:nil];
}

#if 0
- (BOOL)window_split:(ViCommand *)command
{
	return [environment ex_split:nil];
}

- (BOOL)window_vsplit:(ViCommand *)command
{
	return [environment ex_vsplit:nil];
}
#endif

- (BOOL)window_totab:(ViCommand *)command
{
	return [[[self window] windowController] moveCurrentViewToNewTab];
}

- (BOOL)window_new:(ViCommand *)command
{
	return [environment ex_new:nil];
}

- (BOOL)scrollPage:(BOOL)isPageScroll vertically:(BOOL)isVertical direction:(int)direction
{
	NSScrollView *scrollView = [[[[self mainFrame] frameView] documentView] enclosingScrollView];

	NSRect bounds = [[scrollView contentView] bounds];
	NSPoint p = bounds.origin;

	CGFloat amount;
	if (isPageScroll) {
		if (isVertical)
			amount = bounds.size.height - [scrollView verticalPageScroll];
		else
			amount = bounds.size.width - [scrollView horizontalPageScroll];
	} else {
		if (isVertical)
			amount = [scrollView verticalLineScroll];
		else
			amount = [scrollView horizontalLineScroll];
	}

	NSRect docBounds = [[scrollView documentView] bounds];

	if (isVertical) {
		p.y = IMAX(p.y + direction*amount, 0);
		if (p.y + bounds.size.height > docBounds.size.height)
			p.y = docBounds.size.height - bounds.size.height;
	} else {
		p.x = IMAX(p.x + direction*amount, 0);
		if (p.x + bounds.size.width > docBounds.size.width)
			p.x = docBounds.size.width - bounds.size.width;
	}

	// XXX: this doesn't animate, why?
	[[scrollView documentView] scrollPoint:p];

	return YES;
}

/* syntax: [count]h */
- (BOOL)move_left:(ViCommand *)command
{
	return [self scrollPage:NO vertically:NO direction:-1];
}

/* syntax: [count]j */
- (BOOL)move_down:(ViCommand *)command
{
	return [self scrollPage:NO vertically:YES direction:1];
}

/* syntax: [count]k */
- (BOOL)move_up:(ViCommand *)command
{
	return [self scrollPage:NO vertically:YES direction:-1];
}

/* syntax: [count]l */
- (BOOL)move_right:(ViCommand *)command
{
	return [self scrollPage:NO vertically:NO direction:1];
}

/* syntax: ^F */
- (BOOL)forward_screen:(ViCommand *)command
{
	return [self scrollPage:YES vertically:YES direction:1];
}

/* syntax: ^B */
- (BOOL)backward_screen:(ViCommand *)command
{
	return [self scrollPage:YES vertically:YES direction:-1];
}

/* syntax: [count]G */
/* syntax: [count]gg */
- (BOOL)goto_line:(ViCommand *)command
{
	int count = command.count;
	BOOL defaultToEOF = [command.mapping.parameter intValue];

	NSScrollView *scrollView = [[[[self mainFrame] frameView] documentView] enclosingScrollView];
	if (count == 1 ||
	    (count == 0 && !defaultToEOF)) {
		/* goto first line */
		[[scrollView documentView] scrollPoint:NSMakePoint(0, 0)];
	} else if (count == 0) {
		/* goto last line */
		NSRect bounds = [[scrollView contentView] bounds];
		NSRect docBounds = [[scrollView documentView] bounds];
		NSPoint p = NSMakePoint(0,
		    IMAX(0, docBounds.size.height - bounds.size.height));
		[[scrollView documentView] scrollPoint:p];
	} else {
		[environment message:@"unsupported count for %@ command",
		    command.mapping.keyString];
		return NO;
	}

	return YES;
}

/* syntax: : */
- (BOOL)ex_command:(ViCommand *)command
{
	[environment executeForTextView:nil];
	return YES;
}

@end

