#import "ViRegexp.h"
#import "ViScope.h"

@class ViBundle;

/** A language syntax.
 */
@interface ViLanguage : NSObject
{
	__weak ViBundle		*_bundle;	// XXX: not retained!
	NSMutableDictionary	*_language;
	NSMutableArray		*_languagePatterns;
	BOOL			 _compiled;
	ViScope			*_scope;
}

@property(nonatomic,readonly) __weak ViBundle *bundle;

/** The top-level scope of the language. */
@property(nonatomic,readonly) ViScope *scope;

@property (nonatomic, readonly) NSString *firstLineMatch;

/**
 * @returns  The scope name of the language.
 */
@property (nonatomic, readonly) NSString *name;

- (id)initWithPath:(NSString *)aPath forBundle:(ViBundle *)aBundle;
- (NSArray *)fileTypes;

/**
 * @returns The display name of the language.
 */
@property (nonatomic, readonly) NSString *displayName;

- (NSArray *)patterns;
- (NSArray *)expandedPatternsForPattern:(NSMutableDictionary *)pattern;
- (NSArray *)expandedPatternsForPattern:(NSMutableDictionary *)pattern baseLanguage:(ViLanguage *)baseLanguage;
- (ViRegexp *)compileRegexp:(NSString *)pattern
 withBackreferencesToRegexp:(ViRegexpMatch *)beginMatch
                  matchText:(const unichar *)matchText;

@end
