#import <Cocoa/Cocoa.h>

@interface NSArray (patterns)

- (BOOL)isEqualToPatternArray:(NSArray *)otherArray;
- (BOOL)isEqualToStringArray:(NSArray *)otherArray;

@end

