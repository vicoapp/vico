/** Convenience NSString functions. */
@interface NSString (additions)

/** Count lines.
 * @returns The number of lines in the string.
 */
- (NSInteger)numberOfLines;

/** Count occurrences of a character.
 * @param ch The character to search for.
 * @returns The number of occurrences of the character.
 */
- (NSUInteger)occurrencesOfCharacter:(unichar)ch;

/** Return the string representation of a key code.
 * @param keyCode The key code to make into a string.
 * @returns The string representation of the key code.
 */
+ (NSString *)stringWithKeyCode:(NSInteger)keyCode;

/** Return the string representation of a key sequence.
 * @param keySequence An array of NSNumbers representing key codes.
 * @returns The string representation of the key codes.
 */
+ (NSString *)stringWithKeySequence:(NSArray *)keySequence;

/** Convert a string to an array of key codes.
 * @returns An array of NSNumbers representing key codes.
 */
- (NSArray *)keyCodes;

+ (NSString *)visualStringWithKeyCode:(NSInteger)keyCode;
+ (NSString *)visualStringWithKeySequence:(NSArray *)keySequence;
+ (NSString *)visualStringWithKeyString:(NSString *)keyString;
- (NSString *)visualKeyString;

/**
 * @returns YES if the string is in uppercase.
 */
- (BOOL)isUppercase;

/**
 * @returns YES if the string is in lowercase.
 */
- (BOOL)isLowercase;
@end

