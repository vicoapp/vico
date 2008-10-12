#import "ViLanguage.h"

@interface ViBundle : NSObject
{
	NSMutableDictionary *info;
	NSMutableArray *languages;
	NSMutableArray *preferences;
	NSMutableDictionary *cachedPreferences;
}
- (id)initWithPath:(NSString *)aPath;
- (NSString *)name;
- (void)addLanguage:(ViLanguage *)lang;
- (void)addPreferences:(NSDictionary *)prefs;
- (NSDictionary *)preferenceItems:(NSString *)prefsName;

@property(readonly) NSMutableArray *languages;

@end
