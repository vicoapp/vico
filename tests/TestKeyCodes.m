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

#import "TestKeyCodes.h"
#import "NSEvent-keyAdditions.h"
#import "NSString-additions.h"

/* I just wanted the Events.h header! */
#import <Carbon/Carbon.h>

@implementation TestKeyCodes

- (NSEvent *)eventForChar:(unichar)ch
                  without:(unichar)without
                    flags:(NSUInteger)flags
                  keycode:(unsigned short)keycode
{
	NSEvent *ev = [NSEvent keyEventWithType:NSKeyDown
				       location:NSMakePoint(0, 0)
				  modifierFlags:flags
				      timestamp:[[NSDate date] timeIntervalSinceNow]
				   windowNumber:0
					context:[NSGraphicsContext currentContext]
				     characters:[NSString stringWithFormat:@"%C", ch]
		    charactersIgnoringModifiers:[NSString stringWithFormat:@"%C", without]
				      isARepeat:NO
					keyCode:keycode];
	return ev;
}

- (void)test:(unichar)ch
     without:(unichar)without
       flags:(NSUInteger)flags
     keycode:(unsigned short)keycode
      expect:(NSInteger)expectedCode
      expect:(NSString *)expectedString
{
	NSEvent *ev = [self eventForChar:ch without:without flags:flags keycode:keycode];
	NSInteger keyCode = [ev normalizedKeyCode];
	STAssertEquals(keyCode, expectedCode, nil);
	NSString *keyString = [NSString stringWithKeyCode:keyCode];
	STAssertEqualObjects(keyString, expectedString, nil);
	NSArray *keys = [keyString keyCodes];
	STAssertEquals([keys count], 1ULL, nil);
	STAssertEquals([[keys objectAtIndex:0] integerValue], keyCode, nil);
}

- (void)test001_a
{
	[self test:'a' without:'a' flags:0 keycode:kVK_ANSI_A expect:'a' expect:@"a"];
}

- (void)test002_cmd_w
{
	[self test:'w' without:'w' flags:0x100108 keycode:kVK_ANSI_W expect:('w' | NSCommandKeyMask) expect:@"<cmd-w>"];
}

- (void)test003_ctrl_a
{
	[self test:0x01 without:'a' flags:0x40101 keycode:kVK_ANSI_A expect:0x01 expect:@"<ctrl-a>"];
}

- (void)test004_ctrl_A
{
	[self test:0x01 without:'A' flags:0x60105 keycode:kVK_ANSI_A expect:('A' | NSControlKeyMask) expect:@"<ctrl-A>"];
}

- (void)test005_ctrl_alt_a
{
	[self test:0x01 without:'a' flags:0xc0121 keycode:kVK_ANSI_A expect:('a' | NSControlKeyMask | NSAlternateKeyMask) expect:@"<ctrl-alt-a>"];
}

- (void)test006_ctrl_right_bracket
{
	/* 'ä' on my swedish keyboard */
	[self test:0x1b without:0xe4 flags:0x40101 keycode:kVK_ANSI_Quote expect:0x1b expect:@"<esc>"];
}

- (void)test007_ctrl_backslash
{
	/* 0xf6 is 'ö' on my swedish keyboard */
	[self test:0x1c without:0xf6 flags:0x40101 keycode:kVK_ANSI_Semicolon expect:0x1c expect:@"<ctrl-\\>"];
}

- (void)test008_ctrl_left_bracket
{
	/* 0xe5 is 'å' on my swedish keyboard */
	[self test:0x1d without:0xe5 flags:0x40101 keycode:kVK_ANSI_LeftBracket expect:0x1d expect:@"<ctrl-]>"];
}

- (void)test009_ctrl_circumflex
{
	[self test:0x1f without:'-' flags:0x40101 keycode:kVK_ANSI_Slash expect:0x1f expect:@"<ctrl-_>"];
}

- (void)test010_enter
{
	[self test:0x0d without:0x0d flags:0 keycode:kVK_Return expect:0x0d expect:@"<cr>"];
}

- (void)test011_shift_enter
{
	[self test:0x0d without:0x0d flags:0x20102 keycode:kVK_Return expect:(0x0d | NSShiftKeyMask) expect:@"<shift-cr>"];
}

- (void)test012_ctrl_enter
{
	[self test:0x0d without:0x0d flags:0x40101 keycode:kVK_Return expect:(0x0d | NSControlKeyMask) expect:@"<ctrl-cr>"];
}

- (void)test013_tab
{
	[self test:0x09 without:0x09 flags:0x100 keycode:kVK_Tab expect:0x09 expect:@"<tab>"];
}

- (void)test014_ctrl_tab
{
	[self test:0x09 without:0x09 flags:0x40101 keycode:kVK_Tab expect:(0x09 | NSControlKeyMask) expect:@"<ctrl-tab>"];
}

- (void)test015_ctrl_y
{
	[self test:0x19 without:0x79 flags:0x40101 keycode:kVK_ANSI_Y expect:0x19 expect:@"<ctrl-y>"];
}

- (void)test016_shift_control_tab_vs_ctrl_y
{
	/* apparently shift-control-tab sends a ctrl-y on my keyboard */
	[self test:0x19 without:0x19 flags:0x60101 keycode:kVK_Tab expect:(0x09 | NSControlKeyMask | NSShiftKeyMask) expect:@"<shift-ctrl-tab>"];
	[self test:0x19 without:0x59 flags:0x60101 keycode:kVK_ANSI_Y expect:('Y' | NSControlKeyMask) expect:@"<ctrl-Y>"];
}

- (void)test017_alt_cmd_down
{
	[self test:0xf701 without:0xf701 flags:0xb80128 keycode:kVK_DownArrow expect:(NSDownArrowFunctionKey | NSAlternateKeyMask | NSCommandKeyMask) expect:@"<alt-cmd-down>"];
}

@end
