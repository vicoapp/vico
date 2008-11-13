#import "ViLanguage.h"

@interface ViBundle : NSObject
{
	NSMutableDictionary *info;
	NSMutableArray *languages;
	NSMutableArray *preferences;
	NSMutableArray *snippets;
	NSMutableDictionary *cachedPreferences;
}
- (id)initWithPath:(NSString *)aPath;
- (NSString *)name;
- (void)addLanguage:(ViLanguage *)lang;
- (void)addPreferences:(NSDictionary *)prefs;
- (NSDictionary *)preferenceItems:(NSString *)prefsName;
- (NSDictionary *)preferenceItems:(NSString *)prefsName includeAllSettings:(BOOL)includeAllSettings;
- (void)addSnippet:(NSDictionary *)snippet;
- (NSString *)tabTrigger:(NSString *)name matchingScopes:(NSArray *)scopes;

@property(readonly) NSMutableArray *languages;

@end
