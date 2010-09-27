#import <Cocoa/Cocoa.h>

@interface NSString (additions)
- (NSInteger)numberOfLines;
- (NSUInteger)occurrencesOfCharacter:(unichar)ch;
@end

