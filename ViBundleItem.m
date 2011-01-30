#import "ViBundleCommand.h"
#include "logging.h"

@implementation ViBundleItem

@synthesize bundle;
@synthesize uuid;
@synthesize name;
@synthesize scope;
@synthesize mode;
@synthesize keyEquivalent;
@synthesize modifierMask;
@synthesize keycode;
@synthesize keyflags;

- (ViBundleItem *)initFromDictionary:(NSDictionary *)dict inBundle:(ViBundle *)aBundle
{
	self = [super init];
	if (self) {
		bundle = aBundle;

		name = [dict objectForKey:@"name"];
		scope = [dict objectForKey:@"scope"];
		uuid = [dict objectForKey:@"uuid"];

		NSString *m = [dict objectForKey:@"mode"];	/* extension: 'insert', 'normal' or 'visual' mode */
		if (m == nil)
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
		keyEquivalent = @"";
		keyflags = 0;
		int i;
		for (i = 0; i < [key length]; i++) {
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
			default:
				keycode = c;
				keyEquivalent = [NSString stringWithFormat:@"%C", c];
				break;
			}
		}

		modifierMask = keyflags;
		if ((keyflags & ~NSControlKeyMask) == 0 && keycode >= 'a' && keycode < 'z') {
			keyflags = 0;
			keycode = keycode - 'a' + 1;
		}

		DEBUG(@"parsed key equivalent [%@] as keycode %C (0x%04x), shift = %s, control = %s, alt = %s, command = %s",
		    key, keycode, keycode,
		    (keyflags & NSShiftKeyMask) ? "YES" : "NO",
		    (keyflags & NSControlKeyMask) ? "YES" : "NO",
		    (keyflags & NSAlternateKeyMask) ? "YES" : "NO",
		    (keyflags & NSCommandKeyMask) ? "YES" : "NO");
	}
	return self;
}

@end

