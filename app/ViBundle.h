#import "ViLanguage.h"
#import "ViCommon.h"
#import "Nu/Nu.h"

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
	NuParser *parser;
}

@property(nonatomic,readonly) NSMutableArray *languages;
@property(nonatomic,readonly) NSString *path;
@property(nonatomic,readonly) NSArray *items;
@property(nonatomic,readonly) NSArray *preferences;

+ (NSColor *)hashRGBToColor:(NSString *)hashRGB;
+ (void)normalizePreference:(NSDictionary *)preference
             intoDictionary:(NSMutableDictionary *)normalizedPreference;
+ (void)setupEnvironment:(NSMutableDictionary *)env
             forTextView:(ViTextView *)textView
	   selectedRange:(NSRange)sel;
+ (void)setupEnvironment:(NSMutableDictionary *)env
             forTextView:(ViTextView *)textView;

- (ViBundle *)initWithDirectory:(NSString *)bundleDirectory;
- (NSString *)supportPath;
- (NSString *)name;
- (NSString *)uuid;
- (NSDictionary *)preferenceItem:(NSString *)prefsName;
- (NSDictionary *)preferenceItems:(NSArray *)prefsNames;
- (NSMenu *)menuForScope:(ViScope *)scope
            hasSelection:(BOOL)hasSelection
                    font:(NSFont *)aFont;

@end
