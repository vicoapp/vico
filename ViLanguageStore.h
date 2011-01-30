#import "ViLanguage.h"
#import "ViBundle.h"

#define ViLanguageStoreBundleLoadedNotification @"ViLanguageStoreBundleLoaded"

@interface ViLanguageStore : NSObject
{
	NSMutableDictionary *languages;
	NSMutableArray *bundles;
	NSMutableDictionary *cachedPreferences;
}
+ (NSString *)bundlesDirectory;
+ (ViLanguageStore *)defaultStore;
- (ViLanguage *)languageForFirstLine:(NSString *)firstLine;
- (ViLanguage *)languageForFilename:(NSString *)aPath;
- (ViLanguage *)languageWithScope:(NSString *)scopeName;
- (ViLanguage *)defaultLanguage;
- (NSArray *)allBundles;
- (NSArray *)languages;
- (NSDictionary *)preferenceItem:(NSString *)prefsName;
- (NSDictionary *)preferenceItems:(NSArray *)prefsNames;
- (NSArray *)snippetsWithTabTrigger:(NSString *)name matchingScopes:(NSArray *)scopes inMode:(ViMode)mode;
- (NSArray *)commandsWithKey:(unichar)keycode andFlags:(unsigned int)flags matchingScopes:(NSArray *)scopes inMode:(ViMode)mode;
- (BOOL)isBundleLoaded:(NSString *)name;
- (BOOL)loadBundleFromDirectory:(NSString *)bundleDirectory;

@end
