#import "ViThemeStore.h"

@implementation ViThemeStore

- (ViTheme *)defaultTheme
{
	ViTheme *defaultTheme = nil;

	NSString *themeName = [[NSUserDefaults standardUserDefaults] objectForKey:@"theme"];
	if(themeName)
		defaultTheme = [self themeWithName:themeName];

	if(defaultTheme == nil)
	{

		defaultTheme = [self themeWithName:@"Mac Classic"];
		if(defaultTheme == nil)
			defaultTheme = [[themes allValues] objectAtIndex:0];
	}
	NSLog(@"theme = %@", defaultTheme);
	return defaultTheme;
}

+ (ViThemeStore *)defaultStore
{
	static ViThemeStore *defaultStore = nil;
	if(defaultStore == nil)
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
	NSArray *themeFiles = [[NSFileManager defaultManager] directoryContentsAtPath:aPath];
	NSString *themeFile;
	for(themeFile in themeFiles)
	{
		if([themeFile hasSuffix:@".tmTheme"])
			[self addThemeWithPath:[NSString stringWithFormat:@"%@/%@", aPath, themeFile]];
	}
}

- (id)init
{
	self = [super init];
	if(self)
	{
		BOOL isDirectory = NO;

		themes = [[NSMutableDictionary alloc] init];

		NSString *bundlesPath = @"/Applications/TextMate.app/Contents/SharedSupport/Themes";
		if([[NSFileManager defaultManager] fileExistsAtPath:bundlesPath isDirectory:&isDirectory] && isDirectory)
			[self addThemesFromBundleDirectory:bundlesPath];
		
		bundlesPath = @"/Library/Application Support/TextMate/Bundles/Themes";
		if([[NSFileManager defaultManager] fileExistsAtPath:bundlesPath isDirectory:&isDirectory] && isDirectory)
			[self addThemesFromBundleDirectory:bundlesPath];
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
