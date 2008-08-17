#import <Cocoa/Cocoa.h>


@interface ViLanguage : NSObject
{
	NSMutableDictionary *language;
	NSMutableArray *languagePatterns;
	NSMutableDictionary *scopeMappingCache;
}
- (id)initWithBundle:(NSString *)bundleName;
- (NSArray *)patterns;
- (NSArray *)fileTypes;
- (NSString *)name;
- (NSDictionary *)patternForScope:(NSString *)aScopeSelector;

@end
