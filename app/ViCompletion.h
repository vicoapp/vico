#import "ViRegexp.h"

@interface ViCompletion : NSObject
{
	NSString *content;
	NSMutableAttributedString *title;
	BOOL titleIsDirty;
	BOOL scoreIsDirty;
	ViRegexpMatch *filterMatch;
	NSUInteger prefixLength;
	BOOL filterIsFuzzy;
	NSFont *font;
	NSColor *markColor;
	NSUInteger location;
	double score;
	id representedObject;
	NSMutableParagraphStyle *titleParagraphStyle;
}

@property (nonatomic, readonly) NSString *content;
@property (nonatomic, readwrite, assign) ViRegexpMatch *filterMatch;
@property (nonatomic, readwrite) NSUInteger prefixLength;
@property (nonatomic, readwrite) BOOL filterIsFuzzy;
@property (nonatomic, readwrite, assign) NSFont *font;
@property (nonatomic, readwrite) NSUInteger location;
@property (nonatomic, readwrite, assign) id representedObject;
@property (nonatomic, readwrite, assign) NSColor *markColor;

+ (id)completionWithContent:(NSString *)aString prefixLength:(NSUInteger)aLength;
+ (id)completionWithContent:(NSString *)aString fuzzyMatch:(ViRegexpMatch *)aMatch;

- (id)initWithContent:(NSString *)aString prefixLength:(NSUInteger)aLength;
- (id)initWithContent:(NSString *)aString fuzzyMatch:(ViRegexpMatch *)aMatch;

- (NSAttributedString *)title;
- (double)score;

@end
