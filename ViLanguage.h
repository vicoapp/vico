#import <Cocoa/Cocoa.h>
#import <OgreKit/OgreKit.h>

@interface ViLanguage : NSObject
{
	NSMutableDictionary *language;
	NSMutableArray *languagePatterns;
	NSMutableDictionary *scopeMappingCache;
	BOOL compiled;
}
- (id)initWithBundle:(NSString *)bundleName;
- (NSArray *)fileTypes;
- (NSString *)firstLineMatch;
- (NSString *)name;
- (NSArray *)patterns;
- (NSArray *)expandedPatternsForPattern:(NSMutableDictionary *)pattern;
- (NSArray *)expandedPatternsForPattern:(NSMutableDictionary *)pattern baseLanguage:(ViLanguage *)baseLanguage;
- (OGRegularExpression *)compileRegexp:(NSString *)pattern withBackreferencesToRegexp:(OGRegularExpressionMatch *)beginMatch;

@end
