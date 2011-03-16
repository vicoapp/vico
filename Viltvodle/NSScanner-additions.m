#import "NSScanner-additions.h"

@implementation NSScanner (additions)

- (BOOL)scanCharacter:(unichar *)ch
{
	if ([self isAtEnd])
		return NO;
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

@end
