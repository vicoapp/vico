#include <oniguruma.h>

@interface ViRegexpMatch : NSObject
{
	OnigRegion *region;
	NSUInteger startLocation;
}

@property(nonatomic,readonly) NSUInteger startLocation;

+ (ViRegexpMatch *)regexpMatchWithRegion:(OnigRegion *)aRegion startLocation:(NSUInteger)aLocation;
- (ViRegexpMatch *)initWithRegion:(OnigRegion *)aRegion startLocation:(NSUInteger)aLocation;
- (NSRange)rangeOfMatchedString;
- (NSRange)rangeOfSubstringAtIndex:(NSUInteger)index;
- (NSUInteger)count;

@end


@interface ViRegexp : NSObject
{
	NSString *_pattern;
	OnigRegex regex;
}

+ (NSCharacterSet *)reservedCharacters;
+ (BOOL)needEscape:(unichar)ch;
+ (NSString *)escape:(NSString *)string inRange:(NSRange)range;
+ (NSString *)escape:(NSString *)string;

- (ViRegexp *)initWithString:(NSString *)aString;
- (ViRegexp *)initWithString:(NSString *)aString options:(int)options;
- (ViRegexp *)initWithString:(NSString *)aString options:(int)options error:(NSError **)outError;
- (BOOL)matchesString:(NSString *)aString;
- (ViRegexpMatch *)matchInString:(NSString *)aString range:(NSRange)aRange;
- (ViRegexpMatch *)matchInString:(NSString *)aString;
- (ViRegexpMatch *)matchInCharacters:(const unichar *)chars range:(NSRange)aRange start:(NSUInteger)aLocation;
- (ViRegexpMatch *)matchInCharacters:(const unichar *)chars options:(int)options range:(NSRange)aRange start:(NSUInteger)aLocation;
- (NSArray *)allMatchesInCharacters:(const unichar *)chars options:(int)options range:(NSRange)aRange start:(NSUInteger)aLocation;
- (NSArray *)allMatchesInCharacters:(const unichar *)chars range:(NSRange)aRange start:(NSUInteger)aLocation;
- (NSArray *)allMatchesInString:(NSString *)aString range:(NSRange)aRange;
- (NSArray *)allMatchesInString:(NSString *)aString options:(int)options;
- (NSArray *)allMatchesInString:(NSString *)aString options:(int)options range:(NSRange)aRange;
- (NSArray *)allMatchesInString:(NSString *)aString range:(NSRange)aRange start:(NSUInteger)aLocation;
- (NSArray *)allMatchesInString:(NSString *)aString;

@end

