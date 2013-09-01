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

#import "ViCommandMenuItemView.h"
#import "NSScanner-additions.h"
#import "NSString-additions.h"
#import "NSObject+SPInvocationGrabbing.h"
#import "NSEvent-keyAdditions.h"
#include "logging.h"

@implementation ViCommandMenuItemView : NSView

@synthesize command = _command;
@synthesize title = _title;
@synthesize attributes = _attributes;

- (void)setCommand:(NSString *)aCommand
{
	NSSize oldSize = [_commandTitle sizeWithAttributes:_attributes];
	_command = aCommand;
	_commandTitle = [_command visualKeyString];
	_commandSize = [_commandTitle sizeWithAttributes:_attributes];

	double dw = _commandSize.width - oldSize.width;
	double dh = _commandSize.height - oldSize.height;

	NSRect frame = [self frame];
	frame.size.width += dw;
	frame.size.height += dh;
	[self setFrame:frame];
}

- (void)setTabTrigger:(NSString *)aTabTrigger
{
	[self setCommand:[aTabTrigger stringByAppendingFormat:@"%C", (unichar)0x21E5]];
}

- (void)setTitle:(NSString *)aTitle
{
	if ([aTitle isEqualToString:_title])
		return;

	NSSize oldSize = [_title sizeWithAttributes:_attributes];
	_title = aTitle;
	_titleSize = [_title sizeWithAttributes:_attributes];

	double dw = _titleSize.width - oldSize.width;
	double dh = _titleSize.height - oldSize.height;

	NSRect frame = [self frame];
	frame.size.width += dw;
	frame.size.height += dh;
	[self setFrame:frame];
}

- (id)initWithTitle:(NSString *)aTitle command:(NSString *)aCommand font:(NSFont *)aFont
{
	if ((self = [super initWithFrame:NSMakeRect(0, 0, 100, 20)]) != nil) {
		double w, h;

		_command = aCommand;
		_commandTitle = [_command visualKeyString];

		[self setAttributes:[NSMutableDictionary dictionaryWithObject:[NSFont menuBarFontOfSize:0]
								       forKey:NSFontAttributeName]];
		_titleSize = [aTitle sizeWithAttributes:_attributes];
		_commandSize = [_commandTitle sizeWithAttributes:_attributes];
		_disabledColor = [NSColor colorWithCalibratedRed:(CGFloat)0xE5/0xFF
							   green:(CGFloat)0xE5/0xFF
							    blue:(CGFloat)0xE5/0xFF
							   alpha:1.0];
		_highlightColor = [NSColor colorWithCalibratedRed:(CGFloat)0x2B/0xFF
							    green:(CGFloat)0x41/0xFF
							     blue:(CGFloat)0xD3/0xFF
							    alpha:1.0];
		_normalColor = [NSColor colorWithCalibratedRed:(CGFloat)0xD5/0xFF
							 green:(CGFloat)0xD5/0xFF
							  blue:(CGFloat)0xD5/0xFF
							 alpha:1.0];

		h = _titleSize.height + 1;
		w = 20 + _titleSize.width + 30 + _commandSize.width + 15;
		[self setFrame:NSMakeRect(0, 0, w, h)];

		_title = aTitle;
		[self setAutoresizingMask:NSViewWidthSizable];
	}
	return self;
}

- (id)initWithTitle:(NSString *)aTitle tabTrigger:(NSString *)aTabTrigger font:(NSFont *)aFont
{
	return [self initWithTitle:aTitle
			   command:[aTabTrigger stringByAppendingFormat:@"%C", (unichar)0x21E5]
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

	[self setAttributes:[NSMutableDictionary dictionaryWithObject:[[[self enclosingMenuItem] menu] font]
							       forKey:NSFontAttributeName]];
	if (!enabled)
		[_attributes setObject:[NSColor disabledControlTextColor]
				forKey:NSForegroundColorAttributeName];
	else if (highlighted)
		[_attributes setObject:[NSColor selectedMenuItemTextColor]
				forKey:NSForegroundColorAttributeName];
	else
		[_attributes setObject:[NSColor controlTextColor]
				forKey:NSForegroundColorAttributeName];
	[_title drawAtPoint:NSMakePoint(21, 1) withAttributes:_attributes];

	NSRect b = [self bounds];
	NSPoint p = NSMakePoint(b.size.width - _commandSize.width - 15, 1);
	NSRect bg = NSMakeRect(p.x - 4, p.y, _commandSize.width + 8, _commandSize.height);
	if (!enabled)
		[_disabledColor set];
	else if (highlighted)
		[_highlightColor set];
	else
		[_normalColor set];
	[[NSBezierPath bezierPathWithRoundedRect:bg xRadius:6 yRadius:6] fill];

	[_commandTitle drawAtPoint:p withAttributes:_attributes];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
	NSMenuItem *item = [self enclosingMenuItem];
	[super viewWillMoveToWindow:newWindow];
	DEBUG(@"item %@ moves to window %@", item, newWindow);

	if (newWindow)
		[[self window] becomeKeyWindow];

	if (newWindow == nil) {
		if ([item isEnabled]) {
			NSMenu *menu = [item menu];
			NSInteger itemIndex = [menu indexOfItem:item];

			// XXX: Hack to force the menuitem to loose the highlight
			[[menu nextRunloop] removeItemAtIndex:itemIndex];
			[[menu nextRunloop] insertItem:item atIndex:itemIndex];
		}
	}
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
}

- (void)mouseUp:(NSEvent *)event
{
	[self performAction];
}

- (BOOL)acceptsFirstResponder
{
	return YES;
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
