@interface NSScanner (additions)
- (BOOL)scanCharacter:(unichar *)ch;
- (BOOL)scanUpToUnescapedCharacter:(unichar)ch intoString:(NSString **)string;
- (BOOL)scanShellVariableIntoString:(NSString **)intoString;
@end

