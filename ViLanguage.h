#import <Cocoa/Cocoa.h>
#import <OgreKit/OgreKit.h>
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
- (ViRegexp *)compileRegexp:(NSString *)pattern withBackreferencesToRegexp:(id)beginMatch;

@end
