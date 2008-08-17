#import "ViAppController.h"
#import "ViThemeStore.h"
#import "MyDocument.h"

@implementation ViAppController

- (id)init
{
	NSLog(@"ViAppController is being initialized!");
	self = [super init];
	[NSApp setDelegate:self];
	return self;
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	NSLog(@"applicationWillFinishLaunching");
	NSArray *themes = [[[ViThemeStore defaultStore] availableThemes] sortedArrayUsingSelector:@selector(compare:)];
	NSString *theme;
	for(theme in themes)
	{
		NSLog(@"adding theme %@", theme);
		NSMenuItem *item = [themeMenu addItemWithTitle:theme action:@selector(setTheme:) keyEquivalent:@""];
		[item setTarget:self];
	}
}

- (void)setTheme:(id)sender
{
	NSLog(@"setTheme");
	NSLog(@"sender is %@", sender);
	NSString *themeName = [sender title];
	ViTheme *theme = [[ViThemeStore defaultStore] themeWithName:themeName];
	NSLog(@"should change theme to %@", themeName);
	NSWindow *window;
	NSArray *windows = [NSApp windows];
	for(window in windows)
	{
		NSLog(@"changing theme for window %@ with title [%@]", window, [window title]);
		[[window delegate] changeTheme:theme];
	}

	[[NSUserDefaults standardUserDefaults] setObject:themeName forKey:@"theme"];
}

@end
