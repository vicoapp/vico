#import "ViWebView.h"
#import "ViCommon.h"
#import "ViWindowController.h"
#import "NSEvent-keyAdditions.h"
#import "NSView-additions.h"
#import "ExParser.h"
#include "logging.h"

@implementation ViWebView

- (void)awakeFromNib
{
	keyManager = [[ViKeyManager alloc] initWithTarget:self
					       defaultMap:[ViMap mapWithName:@"webMap"]];
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

- (void)swipeWithEvent:(NSEvent *)event
{
	BOOL rc = NO, keep_message = NO;

	DEBUG(@"got swipe event %@", event);

	if ([event deltaX] > 0)
		rc = [self goBack];
	else if ([event deltaX] < 0)
		rc = [self goForward];

	if (rc == YES && !keep_message)
		MESSAGE(@""); // erase any previous message
}

- (void)keyManager:(ViKeyManager *)keyManager
  partialKeyString:(NSString *)keyString
{
	MESSAGE(@"%@", keyString);
}

- (void)keyManager:(ViKeyManager *)aKeyManager
      presentError:(NSError *)error
{
	MESSAGE(@"%@", [error localizedDescription]);
}

- (BOOL)keyManager:(ViKeyManager *)keyManager
   evaluateCommand:(ViCommand *)command
{
	DEBUG(@"command is %@", command);
	MESSAGE(@""); // erase any previous message
	id target = [self targetForSelector:command.action];
	if (target == nil) {
		MESSAGE(@"Command %@ not implemented.",
		    command.mapping.keyString);
		return NO;
	}

	return (BOOL)[target performSelector:command.action withObject:command];
}

- (BOOL)scrollPage:(BOOL)isPageScroll
        vertically:(BOOL)isVertical
         direction:(int)direction
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
		MESSAGE(@"unsupported count for %@ command",
		    command.mapping.keyString);
		return NO;
	}

	return YES;
}

/* syntax: : */
- (BOOL)ex_command:(ViCommand *)command
{
	NSString *exline = [self getExStringForCommand:command];
	if (exline == nil)
		return NO;

	NSError *error = nil;
	ExCommand *ex = [[ExParser sharedParser] parse:exline error:&error];
	if (error) {
		MESSAGE(@"%@", [error localizedDescription]);
		return NO;
	}

	if ([self evalExCommand:ex]) {
		command.caret = ex.caret;
		if ([ex.messages count] > 0)
			MESSAGE(@"%@", [ex.messages lastObject]);
		return YES;
	}

	return NO;
}

@end

