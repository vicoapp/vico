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

#import "ViBundleCommand.h"
#import "NSString-additions.h"
#include "logging.h"

@implementation ViBundleItem

@synthesize bundle = _bundle;
@synthesize uuid = _uuid;
@synthesize name = _name;
@synthesize scopeSelector = _scopeSelector;
@synthesize mode = _mode;
@synthesize keyEquivalent = _keyEquivalent;
@synthesize modifierMask = _modifierMask;
@synthesize keyCode = _keyCode;
@synthesize tabTrigger = _tabTrigger;

- (ViBundleItem *)initFromDictionary:(NSDictionary *)dict
                            inBundle:(ViBundle *)aBundle
{
	if ((self = [super init]) != nil) {
		_bundle = aBundle;	// XXX: not retained!

		_name = [[dict objectForKey:@"name"] retain];
		_scopeSelector = [[dict objectForKey:@"scope"] retain];
		_uuid = [[dict objectForKey:@"uuid"] retain];
		_tabTrigger = [[dict objectForKey:@"tabTrigger"] retain];

		if (_uuid == nil) {
			INFO(@"missing uuid in bundle item %@", _name);
			[self release];
			return nil;
		}

		/* extension: 'any', 'insert', 'normal' or 'visual' mode */
		NSString *m = [dict objectForKey:@"mode"];
		if (m == nil || [m isEqualToString:@"any"])
			_mode = ViAnyMode;
		else if ([m isEqualToString:@"insert"])
			_mode = ViInsertMode;
		else if ([m isEqualToString:@"normal"] || [m isEqualToString:@"command"])
			_mode = ViNormalMode;
		else if ([m isEqualToString:@"visual"])
			_mode = ViVisualMode;
		else {
			INFO(@"unknown mode %@, using any mode", m);
			_mode = ViAnyMode;
		}

		NSString *key = [dict objectForKey:@"keyEquivalent"];
		if ([key length] > 0) {
			NSRange r = NSMakeRange([key length] - 1, 1);
			unsigned int keyflags = 0;
			_keyCode = [key characterAtIndex:r.location];
			_keyEquivalent = [[key substringWithRange:r] retain];
			for (int i = 0; i < [key length] - 1; i++) {
				unichar c = [key characterAtIndex:i];
				switch (c)
				{
				case '^':
					keyflags |= NSControlKeyMask;
					break;
				case '@':
					keyflags |= NSCommandKeyMask;
					break;
				case '~':
					keyflags |= NSAlternateKeyMask;
					break;
				case '$':
					keyflags |= NSShiftKeyMask;
					break;
				default:
					INFO(@"unknown key modifier '%C'", c);
					break;
				}
			}

			_modifierMask = keyflags;

			if (keyflags == NSControlKeyMask) {
				if (_keyCode >= 'a' && _keyCode <= 'z') {
					keyflags = 0;
					_keyCode = _keyCode - 'a' + 1;
				} else if (_keyCode >= '[' && _keyCode <= '_') {
					keyflags = 0;
					_keyCode = _keyCode - 'A' + 1;
				}
			}

			if ([_keyEquivalent isUppercase])
				keyflags |= NSShiftKeyMask;

			/* Same test as in keyDown: */
			if ((0x20 < _keyCode && _keyCode < 0x7f) || _keyCode == 0x1E)
				keyflags &= ~NSShiftKeyMask;

			_keyCode |= keyflags;

			DEBUG(@"parsed key equivalent [%@] as [%@] keycode 0x%04x,"
			    " flags 0x%04X: s=%s, c=%s, a=%s, C=%s, name is %@",
			    key, _keyEquivalent, _keyCode, keyflags,
			    (keyflags & NSShiftKeyMask) ? "YES" : "NO",
			    (keyflags & NSControlKeyMask) ? "YES" : "NO",
			    (keyflags & NSAlternateKeyMask) ? "YES" : "NO",
			    (keyflags & NSCommandKeyMask) ? "YES" : "NO", _name);
		
			if (_keyCode == 0x1B) {
				/* Prevent mapping of escape. */
				INFO(@"refusing to map <esc> to bundle command %@", _name);
				_keyEquivalent = @"";
				_keyCode = -1;
			}
		} else {
			_keyEquivalent = @"";
			_keyCode = -1;
		}
	}

	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	[_uuid release];
	[_name release];
	[_scopeSelector release];
	[_keyEquivalent release];
	[_tabTrigger release];
	[super dealloc];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@: %p, %@, scope %@>",
	    NSStringFromClass([self class]), self, _name, _scopeSelector];
}

@end

