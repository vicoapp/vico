#import "ViWebView.h"
#import "ViCommon.h"
#import "logging.h"

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
	if (![self respondsToSelector:NSSelectorFromString(command.method)] ||
	    (command.motion_method && ![self respondsToSelector:NSSelectorFromString(command.motion_method)])) {
		[environment message:@"Command not implemented."];
		return NO;
	}

	DEBUG(@"perform command %@", command.method);
	BOOL ok = (NSUInteger)[self performSelector:NSSelectorFromString(command.method) withObject:command];

	if (ok)	// erase any previous message
		[environment message:@""];

	return ok;
}

- (void)switch_tab:(int)arg
{
	if (arg-- == 0)
		arg = 9;
        [environment selectTabAtIndex:arg];
}

- (void)handleKey:(unichar)charcode flags:(unsigned int)flags
{
	DEBUG(@"handle key '%C' w/flags 0x%04x", charcode, flags);

	if (parser.partial && (flags & ~NSNumericPadKeyMask) != 0) {
		[environment message:@"Vi command interrupted by key equivalent."];
		[parser reset];
	}

	/* Special handling of command-[0-9] to switch tabs. */
	if (flags == NSCommandKeyMask && charcode >= '0' && charcode <= '9') {
		[self switch_tab:charcode - '0'];
		return;
	}

	if ((flags & ~NSNumericPadKeyMask) != 0) {
		DEBUG(@"unhandled key equivalent %C/0x%04X", charcode, flags);
		return;
	}

	if (parser.complete)
		[parser reset];

	[parser pushKey:charcode];
	if (parser.complete)
		[self evaluateCommand:parser];
}

- (void)keyDown:(NSEvent *)theEvent
{
	
	// XXX: can we move this to a category on NSEvent, please?

	// http://sigpipe.macromates.com/2005/09/24/deciphering-an-nsevent/
	// given theEvent (NSEvent*) figure out what key 
	// and modifiers we actually want to look at, 
	// to compare it with a menu key description
 
	unsigned int quals = [theEvent modifierFlags];

	NSString *str = [theEvent characters];
	NSString *strWithout = [theEvent charactersIgnoringModifiers];

	unichar ch = [str length] ? [str characterAtIndex:0] : 0;
	unichar without = [strWithout length] ? [strWithout characterAtIndex:0] : 0;

	if (!(quals & NSNumericPadKeyMask)) {
		if (quals & NSControlKeyMask) {
			if (ch < 0x20)
				quals &= ~NSControlKeyMask;
			else
				ch = without;
		} else if (quals & NSAlternateKeyMask) {
			if (0x20 < ch && ch < 0x7f && ch != without)
				quals &= ~NSAlternateKeyMask;
			else
				ch = without;
		} else if ((quals & (NSCommandKeyMask | NSShiftKeyMask)) == (NSCommandKeyMask | NSShiftKeyMask))
			ch = without;

		if ((0x20 < ch && ch < 0x7f) || ch == 0x19)
			quals &= ~NSShiftKeyMask;
	}
 
	// the resulting values
	unichar key = ch;
	unsigned int modifiers = quals & (NSNumericPadKeyMask | NSShiftKeyMask | NSControlKeyMask | NSAlternateKeyMask | NSCommandKeyMask);

	DEBUG(@"key = %C (0x%04x), shift = %s, control = %s, alt = %s, command = %s",
	    key, key,
	    (modifiers & NSShiftKeyMask) ? "YES" : "NO",
	    (modifiers & NSControlKeyMask) ? "YES" : "NO",
	    (modifiers & NSAlternateKeyMask) ? "YES" : "NO",
	    (modifiers & NSCommandKeyMask) ? "YES" : "NO"
	);

//	[super keyDown:theEvent];
//	DEBUG(@"done interpreting key events, inserted key = %s", insertedKey ? "YES" : "NO");

//	if (!insertedKey && ![self hasMarkedText])
		[self handleKey:key flags:modifiers];
//	insertedKey = NO;
}

- (BOOL)window_left:(ViCommand *)command
{
	return [environment selectViewAtPosition:ViViewLeft relativeTo:self];
}

- (BOOL)window_down:(ViCommand *)command
{
	return [environment selectViewAtPosition:ViViewDown relativeTo:self];
}

- (BOOL)window_up:(ViCommand *)command
{
	return [environment selectViewAtPosition:ViViewUp relativeTo:self];
}

- (BOOL)window_right:(ViCommand *)command
{
	return [environment selectViewAtPosition:ViViewRight relativeTo:self];
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
- (BOOL)goto_line:(ViCommand *)command
{
	int count = command.count;

	NSScrollView *scrollView = [[[[self mainFrame] frameView] documentView] enclosingScrollView];
	if (count == 1 || (count == 0 && command.key == 'g')) {
		/* goto first line */
		[[scrollView documentView] scrollPoint:NSMakePoint(0, 0)];
	} else if (count == 0) {
		/* goto last line */
		NSRect bounds = [[scrollView contentView] bounds];
		NSRect docBounds = [[scrollView documentView] bounds];
		[[scrollView documentView] scrollPoint:NSMakePoint(0, IMAX(0, docBounds.size.height - bounds.size.height))];
	} else {
		[environment message:@"unsupported count for G command"];
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

