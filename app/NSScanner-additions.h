@interface NSScanner (additions)
- (BOOL)scanCharacter:(unichar *)ch;
- (BOOL)scanUpToUnescapedCharacter:(unichar)toChar
                        intoString:(NSString **)string
                      stripEscapes:(BOOL)stripEscapes;
- (BOOL)scanUpToUnescapedCharacter:(unichar)toChar
                        intoString:(NSString **)string;
- (BOOL)scanShellVariableIntoString:(NSString **)intoString;
- (BOOL)scanString:(NSString *)aString;
- (BOOL)scanKeyCode:(NSInteger *)intoKeyCode;
@end

