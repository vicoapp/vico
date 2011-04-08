#import "ViRegexp.h"

@interface ViCompletion : NSObject
{
	NSString *content;
	NSMutableAttributedString *title;
	ViRegexpMatch *filter;
	NSUInteger prefixLength;
	BOOL filterIsFuzzy;
	NSFont *font;
	NSUInteger location;
	double score;
}

@property (readonly, assign) NSMutableAttributedString *title;
@property (readonly, assign) NSString *content;
@property (readwrite, assign) ViRegexpMatch *filter;
@property (readwrite) NSUInteger prefixLength;
@property (readwrite) BOOL filterIsFuzzy;
@property (readwrite, assign) NSFont *font;
@property (readwrite) NSUInteger location;
@property (readonly) double score;

+ (id)completionWithContent:(NSString *)aString prefixLength:(NSUInteger)aLength;
+ (id)completionWithContent:(NSString *)aString fuzzyMatch:(ViRegexpMatch *)aMatch;

- (id)initWithContent:(NSString *)aString prefixLength:(NSUInteger)aLength;
- (id)initWithContent:(NSString *)aString fuzzyMatch:(ViRegexpMatch *)aMatch;

@end
