#import <Cocoa/Cocoa.h>

@interface NSTextStorage (additions)

- (NSInteger)locationForStartOfLine:(NSUInteger)aLineNumber;
- (NSUInteger)lineNumberAtLocation:(NSUInteger)aLocation;

@end
