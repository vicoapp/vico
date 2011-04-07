#import "ViTheme.h"

@interface ViThemeStore : NSObject
{
	NSMutableDictionary *themes;
}
+ (ViTheme *)defaultTheme;
+ (ViThemeStore *)defaultStore;
- (NSArray *)availableThemes;
- (ViTheme *)themeWithName:(NSString *)aName;
- (ViTheme *)defaultTheme;

@end
