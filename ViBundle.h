#import "ViLanguage.h"

@class ViBundleCommand;

@interface ViBundle : NSObject
{
	NSString *path;
	NSMutableDictionary *info;
	NSMutableArray *languages;
	NSMutableArray *preferences;
	NSMutableArray *snippets;
	NSMutableArray *commands;
	NSMutableDictionary *cachedPreferences;
	NSMutableDictionary *uuids;
}

+ (NSColor *)hashRGBToColor:(NSString *)hashRGB;
+ (void)normalizePreference:(NSDictionary *)preference intoDictionary:(NSMutableDictionary *)normalizedPreference;

- (id)initWithPath:(NSString *)aPath;
- (NSString *)supportPath;
- (NSString *)name;
- (void)addLanguage:(ViLanguage *)lang;
- (void)addPreferences:(NSMutableDictionary *)prefs;
- (NSDictionary *)preferenceItem:(NSString *)prefsName;
- (NSDictionary *)preferenceItems:(NSArray *)prefsNames;
- (void)addSnippet:(NSDictionary *)snippet;
- (void)addCommand:(NSMutableDictionary *)command;
- (ViBundleCommand *)commandWithKey:(unichar)keycode andFlags:(unsigned int)flags matchingScopes:(NSArray *)scopes;
- (NSString *)tabTrigger:(NSString *)name matchingScopes:(NSArray *)scopes;
- (NSMenu *)menuForScopes:(NSArray *)scopes;

@property(readonly) NSMutableArray *languages;
@property(readonly) NSMutableArray *commands;
@property(readonly) NSString *path;

@end
