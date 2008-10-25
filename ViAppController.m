#import "ViAppController.h"
#import "ViThemeStore.h"
#import "ViLanguageStore.h"
#import "ViDocument.h"

@implementation ViAppController

@synthesize lastSearchPattern;
@synthesize lastSearchRegexp;

- (id)init
{
	self = [super init];
	if (self)
	{
		[NSApp setDelegate:self];
		sharedBuffers = [[NSMutableDictionary alloc] init];
	}
	return self;
}

// Application Delegate method
// stops the application from creating an untitled document on load
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	return YES;
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	NSArray *themes = [[[ViThemeStore defaultStore] availableThemes] sortedArrayUsingSelector:@selector(compare:)];
	NSString *theme;
	for (theme in themes)
	{
		NSMenuItem *item = [themeMenu addItemWithTitle:theme action:@selector(setTheme:) keyEquivalent:@""];
		[item setTarget:self];
	}

	/* initialize default defaults */
	[[NSUserDefaults standardUserDefaults] registerDefaults:
		[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt:8], @"shiftwidth",
			[NSNumber numberWithInt:8], @"tabstop",
			[NSNumber numberWithBool:YES], @"autoindent",
			[NSNumber numberWithBool:YES], @"ignorecase",
			[NSNumber numberWithBool:YES], @"expandtabs",
			nil]];

	/* initialize languages */
	[ViLanguageStore defaultStore];
}

- (IBAction)setTheme:(id)sender
{
	NSString *themeName = [sender title];
	ViTheme *theme = [[ViThemeStore defaultStore] themeWithName:themeName];

	ViDocument *doc;
	for (doc in [[NSDocumentController sharedDocumentController] documents])
	{
		[doc changeTheme:theme];
	}

	[[NSUserDefaults standardUserDefaults] setObject:themeName forKey:@"theme"];
}

- (IBAction)setPageGuide:(id)sender
{
	int page_guide_column = [sender tag];

	ViDocument *doc;
	for (doc in [[NSDocumentController sharedDocumentController] documents])
	{
		[doc setPageGuide:page_guide_column];
	}

	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:page_guide_column] forKey:@"pageGuide"];
}

- (NSMutableDictionary *)sharedBuffers
{
	return sharedBuffers;
}

@end
