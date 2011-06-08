#import "ViRegexp.h"

@interface ViSyntaxMatch : NSObject
{
	ViRegexpMatch *beginMatch;
	ViRegexpMatch *endMatch;
	NSMutableDictionary *pattern;
	int patternIndex;
	NSUInteger beginLocation;
	NSUInteger beginLength;
}

- (id)initWithMatch:(ViRegexpMatch *)aMatch andPattern:(NSMutableDictionary *)aPattern atIndex:(int)i;
- (NSComparisonResult)sortByLocation:(ViSyntaxMatch *)match;
- (ViRegexp *)endRegexp;
- (NSUInteger)endLocation;
- (NSString *)scope;
- (NSRange)matchedRange;
- (BOOL)isSingleLineMatch;
- (NSString *)description;
- (void)setEndMatch:(ViRegexpMatch *)aMatch;
- (void)setBeginLocation:(NSUInteger)aLocation;

@property(nonatomic,readonly) int patternIndex;
@property(nonatomic,readonly) NSMutableDictionary *pattern;
@property(nonatomic,readonly) NSUInteger beginLocation;
@property(nonatomic,readonly) NSUInteger beginLength;
@property(nonatomic,readonly) ViRegexpMatch *beginMatch;
@property(nonatomic,readonly) ViRegexpMatch *endMatch;

@end

