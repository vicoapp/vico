@interface NSString (additions)
- (NSInteger)numberOfLines;
- (NSUInteger)occurrencesOfCharacter:(unichar)ch;
+ (NSString *)stringWithKeyCode:(NSInteger)keyCode;
+ (NSString *)stringWithKeySequence:(NSArray *)keySequence;
- (NSArray *)keyCodes;
@end

