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
- (NSString *)tabTrigger:(NSString *)name matchingScopes:(NSArray *)scopes;
- (BOOL)isBundleLoaded:(NSString *)name;
- (BOOL)loadBundleFromDirectory:(NSString *)bundleDirectory;

@end
