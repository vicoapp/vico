#import <Cocoa/Cocoa.h>
#import "ViRegexp.h"

@class ViBundle;

@interface ViLanguage : NSObject
{
	ViBundle *bundle;
	NSMutableDictionary *language;
	NSMutableArray *languagePatterns;
	NSMutableDictionary *scopeMappingCache;
	BOOL compiled;
}

@property(readonly) ViBundle *bundle;

- (id)initWithPath:(NSString *)aPath forBundle:(ViBundle *)aBundle;
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
