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
	for(window in [NSApp windows])
	{
		[[window delegate] changeTheme:theme];
	}
}

@end
