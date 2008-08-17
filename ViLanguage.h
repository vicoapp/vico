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
- (NSString *)name;
- (NSArray *)patterns;
- (NSArray *)expandedPatternsForPattern:(NSMutableDictionary *)pattern;
- (OGRegularExpression *)compileRegexp:(NSString *)pattern withBackreferencesToRegexp:(OGRegularExpressionMatch *)beginMatch;

@end
