#import <Cocoa/Cocoa.h>
#import "ViRegexp.h"

@interface ViLanguage : NSObject
{
	NSMutableDictionary *language;
	NSMutableArray *languagePatterns;
	NSMutableDictionary *scopeMappingCache;
	BOOL compiled;
}

- (NSArray *)fileTypes;
- (NSString *)firstLineMatch;
- (NSString *)name;
- (NSString *)displayName;
- (NSArray *)patterns;
- (NSArray *)expandedPatternsForPattern:(NSMutableDictionary *)pattern;
- (NSArray *)expandedPatternsForPattern:(NSMutableDictionary *)pattern baseLanguage:(ViLanguage *)baseLanguage;
- (ViRegexp *)compileRegexp:(NSString *)pattern;
- (ViRegexp *)compileRegexp:(NSString *)pattern withBackreferencesToRegexp:(ViRegexpMatch *)beginMatch matchText:(const unichar *)matchText;

@end
