@interface NSScanner (additions)
- (unichar)peek;
- (void)inc;
- (BOOL)expectCharacter:(unichar)ch;
- (BOOL)scanCharacter:(unichar *)ch;
- (BOOL)scanUpToUnescapedCharacterFromSet:(NSCharacterSet *)toCharSet
			       intoString:(NSString **)string
			     stripEscapes:(BOOL)stripEscapes;
- (BOOL)scanUpToUnescapedCharacter:(unichar)toChar
                        intoString:(NSString **)string
                      stripEscapes:(BOOL)stripEscapes;
- (BOOL)scanUpToUnescapedCharacter:(unichar)toChar
                        intoString:(NSString **)string;
- (BOOL)scanShellVariableIntoString:(NSString **)intoString;
- (BOOL)scanString:(NSString *)aString;
- (BOOL)scanKeyCode:(NSInteger *)intoKeyCode;
- (void)skipWhitespace;
@end

