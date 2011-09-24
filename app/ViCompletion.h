#import "ViRegexp.h"

@interface ViCompletion : NSObject
{
	NSString			*_content;
	NSMutableAttributedString	*_title;
	BOOL				 _titleIsDirty;
	BOOL				 _scoreIsDirty;
	ViRegexpMatch			*_filterMatch;
	BOOL				 _filterIsFuzzy;
	NSUInteger			 _prefixLength;
	NSFont				*_font;
	NSColor				*_markColor;
	NSUInteger			 _location;
	double				 _score;
	id				 _representedObject;
	NSMutableParagraphStyle		*_titleParagraphStyle;
}

@property (nonatomic, readonly) NSString *content;
@property (nonatomic, readwrite, retain) ViRegexpMatch *filterMatch;
@property (nonatomic, readwrite) NSUInteger prefixLength;
@property (nonatomic, readwrite) BOOL filterIsFuzzy;
@property (nonatomic, readwrite, retain) NSFont *font;
@property (nonatomic, readwrite) NSUInteger location;
@property (nonatomic, readwrite, retain) id representedObject;
@property (nonatomic, readwrite, retain) NSColor *markColor;
@property (nonatomic, readwrite, retain) NSAttributedString *title;
@property (nonatomic, readonly) double score;

+ (id)completionWithContent:(NSString *)aString;
+ (id)completionWithContent:(NSString *)aString fuzzyMatch:(ViRegexpMatch *)aMatch;

- (id)initWithContent:(NSString *)aString;
- (id)initWithContent:(NSString *)aString fuzzyMatch:(ViRegexpMatch *)aMatch;

- (void)updateTitle;
- (void)calcScore;

@end
