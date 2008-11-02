#import <Cocoa/Cocoa.h>

#include <oniguruma.h>

@interface ViRegexpMatch : NSObject
{
	OnigRegion *region;
	NSUInteger startLocation;
}

+ (ViRegexpMatch *)regexpMatchWithString:(NSString *)aString region:(OnigRegion *)aRegion startLocation:(NSUInteger)aLocation;
- (ViRegexpMatch *)initWithString:(NSString *)aString region:(OnigRegion *)aRegion startLocation:(NSUInteger)aLocation;
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
- (NSArray *)allMatchesInString:(NSString *)aString range:(NSRange)aRange;

@end

