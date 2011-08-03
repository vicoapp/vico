#import "ViRegexp.h"
#import "ViScope.h"

@class ViBundle;

/** A language syntax.
 */
@interface ViLanguage : NSObject
{
	ViBundle *bundle;
	NSMutableDictionary *language;
	NSMutableArray *languagePatterns;
	BOOL compiled;
	ViScope *scope;
}

@property(nonatomic,readonly) ViBundle *bundle;

/** The top-level scope of the language. */
@property(nonatomic,readonly) ViScope *scope;

- (id)initWithPath:(NSString *)aPath forBundle:(ViBundle *)aBundle;
- (NSArray *)fileTypes;
- (NSString *)firstLineMatch;

/**
 * @returns  The scope name of the language.
 */
- (NSString *)name;

/**
 * @returns The display name of the language.
 */
- (NSString *)displayName;

- (NSArray *)patterns;
- (NSArray *)expandedPatternsForPattern:(NSMutableDictionary *)pattern;
- (NSArray *)expandedPatternsForPattern:(NSMutableDictionary *)pattern baseLanguage:(ViLanguage *)baseLanguage;
- (ViRegexp *)compileRegexp:(NSString *)pattern;
- (ViRegexp *)compileRegexp:(NSString *)pattern
 withBackreferencesToRegexp:(ViRegexpMatch *)beginMatch
                  matchText:(const unichar *)matchText;

@end
