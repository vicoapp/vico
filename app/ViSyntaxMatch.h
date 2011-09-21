#import "ViRegexp.h"

@interface ViSyntaxMatch : NSObject
{
	ViRegexpMatch		*_beginMatch;
	ViRegexpMatch		*_endMatch;
	NSMutableDictionary	*_pattern;
	int			 _patternIndex;
	NSUInteger		 _beginLocation;
	NSUInteger		 _beginLength;
}

@property(nonatomic,readonly) int patternIndex;
@property(nonatomic,readonly) NSMutableDictionary *pattern;
@property(nonatomic,readwrite) NSUInteger beginLocation;
@property(nonatomic,readonly) NSUInteger beginLength;
@property(nonatomic,readonly) ViRegexpMatch *beginMatch;
@property(nonatomic,readwrite,retain) ViRegexpMatch *endMatch;

- (id)initWithMatch:(ViRegexpMatch *)aMatch andPattern:(NSMutableDictionary *)aPattern atIndex:(int)i;
- (NSComparisonResult)sortByLocation:(ViSyntaxMatch *)match;
- (ViRegexp *)endRegexp;
- (NSUInteger)endLocation;
- (NSString *)scope;
- (NSRange)matchedRange;
- (BOOL)isSingleLineMatch;
- (NSString *)description;

@end

