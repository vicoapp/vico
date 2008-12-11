#import "ViAppController.h"
#import "ViThemeStore.h"
#import "ViLanguageStore.h"
#import "ViDocument.h"

@implementation ViAppController

@synthesize lastSearchPattern;

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
			[NSNumber numberWithBool:YES], @"number",
			[NSNumber numberWithBool:YES], @"autocollapse",
			[NSNumber numberWithBool:NO], @"hidetab",
			nil]];

	/* initialize languages */
	[ViLanguageStore defaultStore];

	NSArray *languages = [[[ViLanguageStore defaultStore] allLanguageNames] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	NSString *language;
	for (language in languages)
	{
		[languageMenu addItemWithTitle:language action:@selector(setLanguage:) keyEquivalent:@""];
	}

	/* initialize commands */
	NSArray *bundles = [[ViLanguageStore defaultStore] allBundles];
	ViBundle *bundle;
	for (bundle in bundles)
	{
		NSMenuItem *item = [commandMenu addItemWithTitle:[bundle name] action:nil keyEquivalent:@""];
		NSMenu *submenu = [[NSMenu alloc] initWithTitle:[bundle name]];
		[item setSubmenu:submenu];
		NSDictionary *command;
		for (command in [bundle commands])
		{
			NSString *key = [command objectForKey:@"keyEquivalent"];
			NSString *keyEquiv = @"";
			NSUInteger modMask = 0;
			int i;
			for (i = 0; i < [key length]; i++)
			{
				unichar c = [key characterAtIndex:i];
				switch (c)
				{
					case '^':
						modMask |= NSControlKeyMask;
						break;
					case '@':
						modMask |= NSCommandKeyMask;
						break;
					case '~':
						modMask |= NSAlternateKeyMask;
						break;
					default:
						keyEquiv = [NSString stringWithFormat:@"%C", c];
						break;
				}
			}

			NSMenuItem *subitem = [submenu addItemWithTitle:[command objectForKey:@"name"] action:@selector(performBundleCommand:) keyEquivalent:keyEquiv];
			[subitem setKeyEquivalentModifierMask:modMask];
			[subitem setRepresentedObject:command];
		}
	}
}

- (IBAction)setTheme:(id)sender
{
	NSString *themeName = [sender title];
	ViTheme *theme = [[ViThemeStore defaultStore] themeWithName:themeName];
	[[NSUserDefaults standardUserDefaults] setObject:themeName forKey:@"theme"];

	ViDocument *doc;
	for (doc in [[NSDocumentController sharedDocumentController] documents])
	{
		[doc changeTheme:theme];
	}
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

- (IBAction)newProject:(id)sender
{
	NSError *error = nil;
	NSDocument *proj = [[NSDocumentController sharedDocumentController] makeUntitledDocumentOfType:@"Project" error:&error];
	INFO(@"proj = %@", proj);
	if (proj)
	{
		[[NSDocumentController sharedDocumentController] addDocument:proj];
		[proj makeWindowControllers];
		[proj showWindows];
	}
	else
		INFO(@"error = %@", error);
}

@end

