#import "NSScanner-additions.h"

@implementation NSScanner (additions)

- (BOOL)scanCharacter:(unichar *)ch
{
	if ([self isAtEnd])
		return NO;
	if (ch)
		*ch = [[self string] characterAtIndex:[self scanLocation]];
	[self setScanLocation:[self scanLocation] + 1];
	return YES;
}

- (BOOL)scanUpToUnescapedCharacter:(unichar)toChar intoString:(NSString **)string
{
	NSMutableString *s = [NSMutableString string];
	unichar ch;
	BOOL gotChar = NO;

	while ([self scanCharacter:&ch]) {
		if (ch == '\\') {
			if ([self scanCharacter:&ch]) {
				if (ch != toChar)
					[s appendString:@"\\"];
				[s appendFormat:@"%C", ch];
			} else
				[s appendString:@"\\"];
		} else if (ch == toChar) {
			/* Don't swallow the end character. */
			gotChar = YES;
			[self setScanLocation:[self scanLocation] - 1];
			break;
		} else
			[s appendFormat:@"%C", ch];
	}

	if (string)
		*string = s;

	return gotChar ? YES : NO;
}

- (BOOL)scanShellVariableIntoString:(NSString **)intoString
{
	NSUInteger startLocation = [self scanLocation];

	BOOL initial = YES;
	NSMutableCharacterSet *shellVariableSet = [[NSMutableCharacterSet alloc] init];
	[shellVariableSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithRange:NSMakeRange('a', 'z' - 'a')]];
	[shellVariableSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithRange:NSMakeRange('A', 'Z' - 'A')]];
	[shellVariableSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"_"]];

	while (![self isAtEnd]) {
		if (![self scanCharactersFromSet:shellVariableSet intoString:nil])
			break;

		if (initial) {
			[shellVariableSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithRange:NSMakeRange('0', '9' - '0')]];
			initial = NO;
		}
	}

	if ([self scanLocation] == startLocation)
		return NO;

	if (intoString)
		*intoString = [[self string] substringWithRange:NSMakeRange(startLocation, [self scanLocation] - startLocation)];
	return YES;
}

- (BOOL)scanString:(NSString *)aString
{
	return [self scanString:aString intoString:nil];
}

- (BOOL)scanKeyCode:(NSInteger *)intoKeyCode
{
	[self setCharactersToBeSkipped:nil];

	unichar ch;
	if (![self scanCharacter:&ch])
		return NO;

	if (ch == '\\') {
		/* Escaped character. */
		if ([self scanCharacter:&ch]) {
			if (intoKeyCode)
				*intoKeyCode = ch;
			return YES;
		} else {
			/* trailing backslash? treat as literal */
			if (intoKeyCode)
				*intoKeyCode = '\\';
			return YES;
		}
	} else if (ch == '<') {
		NSUInteger oldLocation = [self scanLocation];
		[self setCaseSensitive:NO];

		unsigned int modifiers = 0;
		BOOL gotModifier;
		do {
			gotModifier = YES;
			if ([self scanString:@"c-"] ||
			    [self scanString:@"ctrl-"] ||
			    [self scanString:@"control-"])
				modifiers |= NSControlKeyMask;
			else if ([self scanString:@"a-"] ||
			         [self scanString:@"m-"] ||
			         [self scanString:@"alt-"] ||
			         [self scanString:@"meta-"])
				modifiers |= NSAlternateKeyMask;
			else if ([self scanString:@"s-"] ||
			         [self scanString:@"shift-"])
				modifiers |= NSShiftKeyMask;
			else if ([self scanString:@"d-"] ||
			         [self scanString:@"cmd-"] ||
			         [self scanString:@"command-"])
				modifiers |= NSCommandKeyMask;
			else
				gotModifier = NO;
		} while (gotModifier);

		unichar key;
		if ([self scanString:@"delete"] ||
		    [self scanString:@"del"])
			key = NSDeleteFunctionKey;
		else if ([self scanString:@"left"])
			key = NSLeftArrowFunctionKey;
		else if ([self scanString:@"right"])
			key = NSRightArrowFunctionKey;
		else if ([self scanString:@"up"])
			key = NSUpArrowFunctionKey;
		else if ([self scanString:@"down"])
			key = NSDownArrowFunctionKey;
		else if ([self scanString:@"pagedown"] ||
		         [self scanString:@"pgdn"])
			key = NSPageDownFunctionKey;
		else if ([self scanString:@"pageup"] ||
		         [self scanString:@"pgup"])
			key = NSPageUpFunctionKey;
		else if ([self scanString:@"home"])
			key = NSHomeFunctionKey;
		else if ([self scanString:@"end"])
			key = NSEndFunctionKey;
		else if ([self scanString:@"insert"] ||
		         [self scanString:@"ins"])
			key = NSInsertFunctionKey;
		else if ([self scanString:@"help"])
			key = NSHelpFunctionKey;
		else if ([self scanString:@"bs"] ||
		         [self scanString:@"backspace"])
			key = 0x7F;
		else if ([self scanString:@"tab"])
			key = 0x09;
		else if ([self scanString:@"escape"] ||
		         [self scanString:@"esc"])
			key = 0x1B;
		else if ([self scanString:@"cr"] ||
		         [self scanString:@"enter"] ||
		         [self scanString:@"return"])
			key = 0x0D;
		else if ([self scanString:@"space"])
			key = ' ';
		else if ([self scanString:@"bar"])
			key = '|';
		else if ([self scanString:@"lt"])
			key = '<';
		else if ([self scanString:@"bslash"] ||
		         [self scanString:@"backslash"])
			key = '\\';
		else if ([self scanString:@"nl"])	/* ctrl-J */
			key = 0x0A;
		else if ([self scanString:@"ff"])	/* ctrl-L */
			key = 0x0C;
		else if ([self scanString:@"nul"])
			key = 0x0;
		else if ([self scanCharacter:&key]) {
			int f;
			if ((key == 'f' || key == 'F') && [self scanInt:&f]) {
				key = NSF1FunctionKey + f - 1;
			} else if (modifiers == NSControlKeyMask &&
			    ((key >= 'a' && key <= 'z') ||
			     key == '@' ||
			     (key >= '[' && key <= '_'))) {
				/* ASCII control character 0x00 - 0x1F. */
				key = tolower(toupper(key) - '@');
				modifiers = 0;
			}
		} else
			goto failed;

		if (![self scanString:@">"])
			goto failed;
		if (intoKeyCode)
			*intoKeyCode = modifiers | key;
		return YES;

failed:
		[self setScanLocation:oldLocation];
		if (intoKeyCode)
			*intoKeyCode = '<';
	} else if (intoKeyCode)
		*intoKeyCode = ch;
	return YES;
}

@end
