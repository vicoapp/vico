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
- (NSMenu *)menuForScopes:(NSArray *)scopes hasSelection:(BOOL)hasSelection font:(NSFont *)aFont;

@property(readonly) NSMutableArray *languages;
@property(readonly) NSString *path;
@property(readonly) NSArray *items;

@end
