#import "ViTheme.h"

@interface ViThemeStore : NSObject
{
	NSMutableDictionary *themes;
}
+ (ViThemeStore *)defaultStore;
- (NSArray *)availableThemes;
- (ViTheme *)themeWithName:(NSString *)aName;
- (ViTheme *)defaultTheme;

@end
