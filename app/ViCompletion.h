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

@property (readonly) NSString *content;
@property (readwrite, assign) ViRegexpMatch *filterMatch;
@property (readwrite) NSUInteger prefixLength;
@property (readwrite) BOOL filterIsFuzzy;
@property (readwrite, assign) NSFont *font;
@property (readwrite) NSUInteger location;
@property (readwrite, assign) id representedObject;
@property (readwrite, assign) NSColor *markColor;

+ (id)completionWithContent:(NSString *)aString prefixLength:(NSUInteger)aLength;
+ (id)completionWithContent:(NSString *)aString fuzzyMatch:(ViRegexpMatch *)aMatch;

- (id)initWithContent:(NSString *)aString prefixLength:(NSUInteger)aLength;
- (id)initWithContent:(NSString *)aString fuzzyMatch:(ViRegexpMatch *)aMatch;

- (NSAttributedString *)title;
- (double)score;

@end
