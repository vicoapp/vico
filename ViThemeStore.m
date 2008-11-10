#import "ViThemeStore.h"
#import "logging.h"

@implementation ViThemeStore

- (ViTheme *)defaultTheme
{
	ViTheme *defaultTheme = nil;

	NSString *themeName = [[NSUserDefaults standardUserDefaults] objectForKey:@"theme"];
	if (themeName)
		defaultTheme = [self themeWithName:themeName];

	if (defaultTheme == nil)
	{

		defaultTheme = [self themeWithName:@"Mac Classic"];
		if (defaultTheme == nil)
			defaultTheme = [[themes allValues] objectAtIndex:0];
	}

	return defaultTheme;
}

+ (ViThemeStore *)defaultStore
{
	static ViThemeStore *defaultStore = nil;
	if (defaultStore == nil)
	{
		defaultStore = [[ViThemeStore alloc] init];
	}
	return defaultStore;
}

- (void)addThemeWithPath:(NSString *)path
{
	ViTheme *theme = [[ViTheme alloc] initWithPath:path];
	[themes setObject:theme forKey:[theme name]];
}

- (void)addThemesFromBundleDirectory:(NSString *)aPath
{
	BOOL isDirectory = NO;
	if ([[NSFileManager defaultManager] fileExistsAtPath:aPath isDirectory:&isDirectory] && isDirectory)
	{
		NSArray *themeFiles = [[NSFileManager defaultManager] directoryContentsAtPath:aPath];
		NSString *themeFile;
		for (themeFile in themeFiles)
		{
			if ([themeFile hasSuffix:@".tmTheme"])
				[self addThemeWithPath:[NSString stringWithFormat:@"%@/%@", aPath, themeFile]];
		}
	}
}

- (id)init
{
	self = [super init];
	if (self)
	{
		themes = [[NSMutableDictionary alloc] init];

		[self addThemesFromBundleDirectory:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Resources/Themes"]];
#if 0
		[self addThemesFromBundleDirectory:@"/Library/Application Support/TextMate/Themes"];
		[self addThemesFromBundleDirectory:[@"~/Library/Application Support/TextMate/Pristine Copy/Themes" stringByExpandingTildeInPath]];
		[self addThemesFromBundleDirectory:[@"~/Library/Application Support/TextMate/Themes" stringByExpandingTildeInPath]];
#endif
		[self addThemesFromBundleDirectory:[@"~/Library/Application Support/xi/Themes" stringByExpandingTildeInPath]];
	}
	return self;
}

- (NSArray *)availableThemes
{
	return [themes allKeys];
}

- (ViTheme *)themeWithName:(NSString *)aName
{
	return [themes objectForKey:aName];
}

@end
