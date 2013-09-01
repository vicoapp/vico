/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ViWebView.h"
#import "ViCommon.h"
#import "ViWindowController.h"
#import "NSEvent-keyAdditions.h"
#import "NSView-additions.h"
#import "ExParser.h"
#include "logging.h"

@implementation ViWebView

@synthesize keyManager = _keyManager;

- (void)awakeFromNib
{
	[self setKeyManager:[ViKeyManager keyManagerWithTarget:self
						    defaultMap:[ViMap mapWithName:@"webMap"]]];
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

- (BOOL)keyManager:(ViKeyManager *)keyManager
  partialKeyString:(NSString *)keyString
{
	MESSAGE(@"%@", keyString);

	return NO;
}

- (void)keyManager:(ViKeyManager *)aKeyManager
      presentError:(NSError *)error
{
	MESSAGE(@"%@", [error localizedDescription]);
}

- (BOOL)keyManager:(ViKeyManager *)keyManager
   evaluateCommand:(ViCommand *)command
{
	MESSAGE(@""); // erase any previous message
	return [self performCommand:command];
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

