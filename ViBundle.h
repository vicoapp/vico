#import "ViLanguage.h"
#import "ViCommon.h"

@class ViBundleCommand;
@class ViTextView;

@interface ViBundle : NSObject
{
	NSString *path;
	NSMutableDictionary *info;
	NSMutableArray *languages;
	NSMutableArray *preferences;
	NSMutableArray *items;
	NSMutableDictionary *cachedPreferences;
	NSMutableDictionary *uuids;
}

+ (NSColor *)hashRGBToColor:(NSString *)hashRGB;
+ (void)normalizePreference:(NSDictionary *)preference intoDictionary:(NSMutableDictionary *)normalizedPreference;
+ (void)setupEnvironment:(NSMutableDictionary *)env forTextView:(ViTextView *)textView;

- (id)initWithPath:(NSString *)aPath;
- (NSString *)supportPath;
- (NSString *)name;
- (void)addLanguage:(ViLanguage *)lang;
- (void)addPreferences:(NSMutableDictionary *)prefs;
- (NSDictionary *)preferenceItem:(NSString *)prefsName;
- (NSDictionary *)preferenceItems:(NSArray *)prefsNames;
- (void)addSnippet:(NSDictionary *)snippet;
- (void)addCommand:(NSMutableDictionary *)command;
- (NSArray *)itemsWithKey:(unichar)keycode
                 andFlags:(unsigned int)flags
           matchingScopes:(NSArray *)scopes
                   inMode:(ViMode)mode;
- (NSArray *)itemsWithTabTrigger:(NSString *)name
                  matchingScopes:(NSArray *)scopes
                          inMode:(ViMode)mode;
- (NSMenu *)menuForScopes:(NSArray *)scopes;

@property(readonly) NSMutableArray *languages;
@property(readonly) NSString *path;

@end
