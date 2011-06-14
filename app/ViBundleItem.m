#import "ViBundleCommand.h"
#include "logging.h"

@implementation ViBundleItem

@synthesize bundle;
@synthesize uuid;
@synthesize name;
@synthesize scopeSelector;
@synthesize mode;
@synthesize keyEquivalent;
@synthesize modifierMask;
@synthesize keyCode;
@synthesize tabTrigger;

- (ViBundleItem *)initFromDictionary:(NSDictionary *)dict
                            inBundle:(ViBundle *)aBundle
{
	self = [super init];
	if (self) {
		bundle = aBundle;

		name = [dict objectForKey:@"name"];
		scopeSelector = [dict objectForKey:@"scope"];
		uuid = [dict objectForKey:@"uuid"];
		tabTrigger = [dict objectForKey:@"tabTrigger"];

		/* extension: 'insert', 'normal' or 'visual' mode */
		NSString *m = [dict objectForKey:@"mode"];
		if (m == nil || [m isEqualToString:@"any"])
			mode = ViAnyMode;
		else if ([m isEqualToString:@"insert"])
			mode = ViInsertMode;
		else if ([m isEqualToString:@"normal"] || [m isEqualToString:@"command"])
			mode = ViNormalMode;
		else if ([m isEqualToString:@"visual"])
			mode = ViVisualMode;
		else {
			INFO(@"unknown mode %@", m);
			return nil;
		}

		NSString *key = [dict objectForKey:@"keyEquivalent"];
		if ([key length] > 0) {
			NSRange r = NSMakeRange([key length] - 1, 1);
			unsigned int keyflags = 0;
			keyCode = [key characterAtIndex:r.location];
			keyEquivalent = [key substringWithRange:r];
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

			modifierMask = keyflags;

			if (keyflags == NSControlKeyMask && keyCode >= 'a' && keyCode < '~') {
				keyflags = 0;
				keyCode = keyCode - 'a' + 1;
			}

			if ([keyEquivalent isEqualToString:[keyEquivalent uppercaseString]] &&
			    ![keyEquivalent isEqualToString:[keyEquivalent lowercaseString]])
				keyflags |= NSShiftKeyMask;

			/* Same test as in keyDown: */
			if ((0x20 < keyCode && keyCode < 0x7f) || keyCode == 0x1E)
				keyflags &= ~NSShiftKeyMask;

			keyCode |= keyflags;

			DEBUG(@"parsed key equivalent [%@] as [%@] keycode 0x%04x,"
			    " flags 0x%04X: s=%s, c=%s, a=%s, C=%s, name is %@",
			    key, keyEquivalent, keyCode, keyflags,
			    (keyflags & NSShiftKeyMask) ? "YES" : "NO",
			    (keyflags & NSControlKeyMask) ? "YES" : "NO",
			    (keyflags & NSAlternateKeyMask) ? "YES" : "NO",
			    (keyflags & NSCommandKeyMask) ? "YES" : "NO", name);
		
			if (keyCode == 0x1B) {
				/* Prevent mapping of escape. */
				INFO(@"refusing to map <esc> to bundle command %@", name);
				keyEquivalent = @"";
				keyCode = -1;
			}
		} else {
			keyEquivalent = @"";
			keyCode = -1;
		}
	}

	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@: %p, %@, scope %@>",
	    NSStringFromClass([self class]), self, name, scopeSelector];
}

@end

