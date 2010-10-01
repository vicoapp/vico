#import <Cocoa/Cocoa.h>
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
- (ViBundle *)bundleForFilename:(NSString *)aPath language:(ViLanguage **)languagePtr;
- (ViBundle *)bundleForFirstLine:(NSString *)firstLine language:(ViLanguage **)languagePtr;
- (ViBundle *)bundleForLanguage:(NSString *)languageName language:(ViLanguage **)languagePtr;
- (ViBundle *)defaultBundleLanguage:(ViLanguage **)languagePtr;
- (ViLanguage *)languageWithScope:(NSString *)scopeName;
- (NSArray *)allLanguageNames;
- (NSArray *)allBundles;
- (NSDictionary *)preferenceItem:(NSString *)prefsName;
- (NSDictionary *)preferenceItems:(NSArray *)prefsNames;
- (NSString *)tabTrigger:(NSString *)name matchingScopes:(NSArray *)scopes;
- (BOOL)isBundleLoaded:(NSString *)name;
- (BOOL)loadBundleFromDirectory:(NSString *)bundleDirectory;

@end
