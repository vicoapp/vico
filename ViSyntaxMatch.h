#import <Cocoa/Cocoa.h>
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

@property(readonly) int patternIndex;
@property(readonly) NSMutableDictionary *pattern;
@property(readonly) NSUInteger beginLocation;
@property(readonly) NSUInteger beginLength;
@property(readonly) ViRegexpMatch *beginMatch;
@property(readonly) ViRegexpMatch *endMatch;

@end

