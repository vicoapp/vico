#import "ViLanguage.h"

@interface ViBundle : NSObject
{
	NSString *path;
	NSMutableDictionary *info;
	NSMutableArray *languages;
	NSMutableArray *preferences;
	NSMutableArray *snippets;
	NSMutableArray *commands;
	NSMutableDictionary *cachedPreferences;
}

- (id)initWithPath:(NSString *)aPath;
- (NSString *)supportPath;
- (NSString *)name;
- (void)addLanguage:(ViLanguage *)lang;
- (void)addPreferences:(NSDictionary *)prefs;
- (NSDictionary *)preferenceItems:(NSString *)prefsName;
- (NSDictionary *)preferenceItems:(NSString *)prefsName includeAllSettings:(BOOL)includeAllSettings;
- (void)addSnippet:(NSDictionary *)snippet;
- (void)addCommand:(NSDictionary *)command;
- (NSString *)tabTrigger:(NSString *)name matchingScopes:(NSArray *)scopes;

@property(readonly) NSMutableArray *languages;
@property(readonly) NSMutableArray *commands;

@end
