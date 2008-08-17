#import <Cocoa/Cocoa.h>


@interface ViLanguage : NSObject
{
	NSMutableDictionary *language;
	NSMutableArray *languagePatterns;
	NSMutableDictionary *scopeMappingCache;
	BOOL compiled;
}
- (id)initWithBundle:(NSString *)bundleName;
- (NSArray *)patternsForScope:(NSString *)scope;
- (NSArray *)fileTypes;
- (NSString *)name;
- (NSDictionary *)patternForScope:(NSString *)aScopeSelector;
- (NSArray *)expandedPatterns:(NSArray *)patterns;

@end
