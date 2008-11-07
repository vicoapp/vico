#import <Cocoa/Cocoa.h>

#include <oniguruma.h>

@interface ViRegexpMatch : NSObject
{
	OnigRegion *region;
	NSUInteger startLocation;
}

+ (ViRegexpMatch *)regexpMatchWithRegion:(OnigRegion *)aRegion startLocation:(NSUInteger)aLocation;
- (ViRegexpMatch *)initWithRegion:(OnigRegion *)aRegion startLocation:(NSUInteger)aLocation;
- (NSRange)rangeOfMatchedString;
- (NSRange)rangeOfSubstringAtIndex:(unsigned)index;

@end


@interface ViRegexp : NSObject
{
	regex_t *regex;
}

+ (ViRegexp *)regularExpressionWithString:(NSString *)aString;
- (ViRegexpMatch *)matchInString:(NSString *)aString range:(NSRange)aRange;
- (ViRegexpMatch *)matchInString:(NSString *)aString;
- (ViRegexpMatch *)matchInCharacters:(const unichar *)chars range:(NSRange)aRange start:(NSUInteger)aLocation;
- (NSArray *)allMatchesInCharacters:(const unichar *)chars range:(NSRange)aRange start:(NSUInteger)aLocation;
- (NSArray *)allMatchesInString:(NSString *)aString range:(NSRange)aRange;
- (NSArray *)allMatchesInString:(NSString *)aString range:(NSRange)aRange start:(NSUInteger)aLocation;

@end

