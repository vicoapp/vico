#import "ViAppController.h"
#import "ViThemeStore.h"
#import "MyDocument.h"

@implementation ViAppController

- (id)init
{
	self = [super init];
	[NSApp setDelegate:self];
	return self;
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	NSArray *themes = [[[ViThemeStore defaultStore] availableThemes] sortedArrayUsingSelector:@selector(compare:)];
	NSString *theme;
	for(theme in themes)
	{
		NSMenuItem *item = [themeMenu addItemWithTitle:theme action:@selector(setTheme:) keyEquivalent:@""];
		[item setTarget:self];
	}
}

- (void)setTheme:(id)sender
{
	NSString *themeName = [sender title];
	ViTheme *theme = [[ViThemeStore defaultStore] themeWithName:themeName];
	NSWindow *window;
	NSArray *windows = [NSApp windows];
	for(window in windows)
	{
		[[window delegate] changeTheme:theme];
	}

	[[NSUserDefaults standardUserDefaults] setObject:themeName forKey:@"theme"];
}

- (IBAction)closeCurrentTab:(id)sender
{
	[[[NSApp keyWindow] delegate] closeCurrentTab];
}

@end
