#import <Cocoa/Cocoa.h>

@interface NSArray (patterns)

- (BOOL)isEqualToPatternArray:(NSArray *)otherArray;
- (u_int64_t)matchesScopes:(NSArray *)scopes;

@end

