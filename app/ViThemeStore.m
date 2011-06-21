#import "ViThemeStore.h"
#import "ViAppController.h"
#import "logging.h"

@implementation ViThemeStore

+ (ViTheme *)defaultTheme
{
	return [[ViThemeStore defaultStore] defaultTheme];
}

+ (NSFont *)font
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSFont *font = [NSFont fontWithName:[defs stringForKey:@"fontname"]
	                               size:[defs floatForKey:@"fontsize"]];
	if (font == nil)
		font = [NSFont userFixedPitchFontOfSize:11.0];
	return font;
}

- (ViTheme *)defaultTheme
{
	ViTheme *defaultTheme = nil;

	NSString *themeName = [[NSUserDefaults standardUserDefaults] objectForKey:@"theme"];
	if (themeName)
		defaultTheme = [self themeWithName:themeName];

	if (defaultTheme == nil) {
		defaultTheme = [self themeWithName:@"Sunset"];
		if (defaultTheme == nil)
			defaultTheme = [[themes allValues] objectAtIndex:0];
	}

	return defaultTheme;
}

+ (ViThemeStore *)defaultStore
{
	static ViThemeStore *defaultStore = nil;
	if (defaultStore == nil)
		defaultStore = [[ViThemeStore alloc] init];
	return defaultStore;
}

- (void)addThemeWithPath:(NSString *)path
{
	ViTheme *theme = [[ViTheme alloc] initWithPath:path];
	if (theme)
		[themes setObject:theme forKey:[theme name]];
}

- (void)addThemesFromBundleDirectory:(NSString *)aPath
{
	BOOL isDirectory = NO;
	if ([[NSFileManager defaultManager] fileExistsAtPath:aPath isDirectory:&isDirectory] && isDirectory) {
		NSArray *themeFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:aPath error:NULL];
		NSString *themeFile;
		for (themeFile in themeFiles) {
			if ([themeFile hasSuffix:@".tmTheme"])
				[self addThemeWithPath:[NSString stringWithFormat:@"%@/%@", aPath, themeFile]];
		}
	}
}

- (id)init
{
	self = [super init];
	if (self) {
		themes = [[NSMutableDictionary alloc] init];

		[self addThemesFromBundleDirectory:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Resources/Themes"]];

		NSURL *url;
		url = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
							     inDomain:NSUserDomainMask
						    appropriateForURL:nil
							       create:NO
								error:nil];
		if (url)
			[self addThemesFromBundleDirectory:[[url path] stringByAppendingPathComponent:@"TextMate/Themes"]];

		[self addThemesFromBundleDirectory:[[ViAppController supportDirectory] stringByAppendingPathComponent:@"Themes"]];
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
