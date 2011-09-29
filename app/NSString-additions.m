#import "NSString-additions.h"
#import "NSScanner-additions.h"
#include "logging.h"

@implementation NSString (additions)

- (NSInteger)numberOfLines
{
	NSInteger i, n;
	NSUInteger eol, end;

	for (i = n = 0; i < [self length]; i = end, n++) {
		[self getLineStart:NULL end:&end contentsEnd:&eol forRange:NSMakeRange(i, 0)];
		if (end == eol)
			break;
	}

	return n;
}

- (NSUInteger)occurrencesOfCharacter:(unichar)ch
{
	NSUInteger n, i;
	for (i = n = 0; i < [self length]; i++)
		if ([self characterAtIndex:i] == ch)
			n++;
	return n;
}

+ (NSString *)stringWithKeyCode:(NSInteger)keyCode
{
	unichar key = keyCode & 0x0000FFFF;
	unsigned int modifiers = keyCode & 0xFFFF0000;

	NSString *special = nil;
	switch (key) {
	case NSDeleteFunctionKey:
		special = @"del"; break;
	case NSLeftArrowFunctionKey:
		special = @"left"; break;
	case NSRightArrowFunctionKey:
		special = @"right"; break;
	case NSUpArrowFunctionKey:
		special = @"up"; break;
	case NSDownArrowFunctionKey:
		special = @"down"; break;
	case NSPageUpFunctionKey:
		special = @"pageup"; break;
	case NSPageDownFunctionKey:
		special = @"pagedown"; break;
	case NSHomeFunctionKey:
		special = @"home"; break;
	case NSEndFunctionKey:
		special = @"end"; break;
	case NSInsertFunctionKey:
		special = @"ins"; break;
	case NSHelpFunctionKey:
		special = @"help"; break;
	case 0x7F:
		special = @"bs"; break;
	case 0x09:
		special = @"tab"; break;
	case 0x1B:
		special = @"esc"; break;
	case 0x0D:
		special = @"cr"; break;
	case 0x00:
		special = @"nul"; break;
	}

	if (key >= NSF1FunctionKey && key <= NSF35FunctionKey)
		special = [NSString stringWithFormat:@"f%i", key - NSF1FunctionKey + 1];

	if (key < 0x20 && key > 0 && key != 0x1B && key != 0x0D && key != 0x09)
		special = [[NSString stringWithFormat:@"ctrl-%C", key + 'A' - 1] lowercaseString];

	NSString *encodedKey;
	if (modifiers) {
		encodedKey = [NSString stringWithFormat:@"<%s%s%s%s%@>",
		    (modifiers & NSShiftKeyMask) ? "shift-" : "",
		    (modifiers & NSControlKeyMask) ? "ctrl-" : "",
		    (modifiers & NSAlternateKeyMask) ? "alt-" : "",
		    (modifiers & NSCommandKeyMask) ? "cmd-" : "",
		    special ?: [NSString stringWithFormat:@"%C", key]];
	} else if (special)
		encodedKey = [NSString stringWithFormat:@"<%@>", special];
	else
		encodedKey = [NSString stringWithFormat:@"%C", key];

	DEBUG(@"encodedKey = %@", encodedKey);
	return encodedKey;
}

+ (NSString *)visualStringWithKeyCode:(NSInteger)keyCode
{
	unichar key = keyCode & 0x0000FFFF;
	unsigned int modifiers = keyCode & 0xFFFF0000;

	switch (key) {
	case NSDeleteFunctionKey:
		key = 0x2326; break;
	case NSLeftArrowFunctionKey:
		key = 0x2190; break;
	case NSRightArrowFunctionKey:
		key = 0x2192; break;
	case NSUpArrowFunctionKey:
		key = 0x2191; break;
	case NSDownArrowFunctionKey:
		key = 0x2193; break;
/*	case NSPageUpFunctionKey:
		key = ; break;
	case NSPageDownFunctionKey:
		key = @"pagedown"; break;*/
	case NSHomeFunctionKey:
		key = 0x2199;
	case NSEndFunctionKey:
		key = 0x2197; break;
/*	case NSInsertFunctionKey:
		key = @"ins"; break;
	case NSHelpFunctionKey:
		key = ; break;*/
	case 0x7F:
		key = 0x232B; break;
	case 0x09:
		key = 0x21E5; break;
	case 0x1B:
		key = 0x238B; break;
	case 0x0D:
		key = 0x21A9; break;
/*	case 0x00:
		key = @"nul"; break;*/
	}

	NSString *special = nil;
	if (key >= NSF1FunctionKey && key <= NSF35FunctionKey)
		special = [NSString stringWithFormat:@"F%i", key - NSF1FunctionKey + 1];

	if (key < 0x20 && key > 0 && key != 0x1B && key != 0x0D && key != 0x09) {
		key = key + 'A' - 1;
		modifiers |= NSControlKeyMask;
	} else if (modifiers && [[NSString stringWithFormat:@"%C", key] isUppercase])
		modifiers |= NSShiftKeyMask;

	NSString *encodedKey = [NSMutableString string];
	if (modifiers) {
		encodedKey = [NSString stringWithFormat:@"%@%@%@%@%@",
		    (modifiers & NSShiftKeyMask) ? [NSString stringWithFormat:@"%C", 0x21E7] : @"",
		    (modifiers & NSControlKeyMask) ? [NSString stringWithFormat:@"%C", 0x2303] : @"",
		    (modifiers & NSAlternateKeyMask) ? [NSString stringWithFormat:@"%C", 0x2325] : @"",
		    (modifiers & NSCommandKeyMask) ? [NSString stringWithFormat:@"%C", 0x2318] : @"",
		    special ?: [[NSString stringWithFormat:@"%C", key] uppercaseString]];
	} else if (special)
		encodedKey = special;
	else
		encodedKey = [NSString stringWithFormat:@"%C", key];

	DEBUG(@"encodedKey = %@", encodedKey);
	return encodedKey;
}

+ (NSString *)stringWithKeySequence:(NSArray *)keySequence
{
	NSMutableString *s = [NSMutableString string];
	for (NSNumber *n in keySequence)
		[s appendString:[self stringWithKeyCode:[n integerValue]]];
	return s;
}

+ (NSString *)stringWithCharacters:(NSArray *)keySequence
{
	NSMutableString *s = [NSMutableString string];
	for (NSNumber *n in keySequence)
		if ([n unsignedIntegerValue] <= 0xFFFF)
			[s appendFormat:@"%C", (unichar)[n unsignedIntegerValue]];
	return s;
}

- (NSArray *)keyCodes
{
	NSMutableArray *keyArray = [NSMutableArray array];
	NSScanner *scan = [NSScanner scannerWithString:self];

	NSInteger keycode;
	while ([scan scanKeyCode:&keycode])
		[keyArray addObject:[NSNumber numberWithInteger:keycode]];

	if (![scan isAtEnd])
		return nil;

	return keyArray;
}

- (BOOL)isUppercase
{
	return [self isEqualToString:[self uppercaseString]] &&
	      ![self isEqualToString:[self lowercaseString]];
}

- (BOOL)isLowercase
{
	return [self isEqualToString:[self lowercaseString]] &&
	      ![self isEqualToString:[self uppercaseString]];
}

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
+ (NSString *)visualStringWithKeySequence:(NSArray *)keySequence
{
	NSMutableString *s = [NSMutableString string];
	BOOL hadModifiers = NO;
	for (NSNumber *n in keySequence) {
		if (hadModifiers)
			[s appendString:@" "];
		NSString *vs = [self visualStringWithKeyCode:[n integerValue]];
		[s appendString:vs];
		hadModifiers = ([vs length] > 1);
	}
	return s;
}

+ (NSString *)visualStringWithKeyString:(NSString *)keyString
{
	return [self visualStringWithKeySequence:[keyString keyCodes]];
}

- (NSString *)visualKeyString
{
	return [NSString visualStringWithKeySequence:[self keyCodes]];
}

@end

