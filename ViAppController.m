#import "ViAppController.h"
#import "ViThemeStore.h"
#import "ViLanguageStore.h"
#import "ViDocument.h"
#import "ViDocumentController.h"
#import "ViPreferencesController.h"
#include "license.h"

@implementation ViAppController

@synthesize lastSearchPattern;

- (id)init
{
	self = [super init];
	if (self) {
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
	/* initialize default defaults */
	[[NSUserDefaults standardUserDefaults] registerDefaults:
		[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt:8], @"shiftwidth",
			[NSNumber numberWithInt:8], @"tabstop",
			[NSNumber numberWithBool:YES], @"autoindent",
			[NSNumber numberWithBool:YES], @"ignorecase",
			[NSNumber numberWithBool:NO], @"expandtabs",
			[NSNumber numberWithBool:YES], @"number",
			[NSNumber numberWithBool:YES], @"autocollapse",
			[NSNumber numberWithBool:YES], @"hidetab",
			[NSNumber numberWithBool:YES], @"searchincr",
			[NSNumber numberWithBool:NO], @"showguide",
			[NSNumber numberWithBool:NO], @"wrap",
			[NSNumber numberWithInt:80], @"guidecolumn",
			[NSNumber numberWithFloat:11.0], @"fontsize",
			@"Menlo Regular", @"fontname",
			@"Mac Classic", @"theme",
			@"(CVS|_darcs|.svn|.git|~$|\\.bak$|\\.o$)", @"skipPattern",
			NSFullUserName(), @"licenseOwner",
			nil]];

	/* Initialize languages and themes. */
	[ViLanguageStore defaultStore];
	[ViThemeStore defaultStore];

	[[commandMenu supermenu] removeItemAtIndex:4];
#if 0
	/* initialize commands */
	NSArray *bundles = [[ViLanguageStore defaultStore] allBundles];
	ViBundle *bundle;
	for (bundle in bundles) {
		NSMenuItem *item = [commandMenu addItemWithTitle:[bundle name] action:nil keyEquivalent:@""];
		NSMenu *submenu = [[NSMenu alloc] initWithTitle:[bundle name]];
		[item setSubmenu:submenu];
		NSDictionary *command;
		for (command in [bundle commands]) {
			NSString *key = [command objectForKey:@"keyEquivalent"];
			NSString *keyEquiv = @"";
			NSUInteger modMask = 0;
			int i;
			for (i = 0; i < [key length]; i++) {
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
#endif

	[[NSUserDefaults standardUserDefaults] addObserver:self
						forKeyPath:@"theme"
						   options:NSKeyValueObservingOptionNew
						   context:NULL];
	[[NSUserDefaults standardUserDefaults] addObserver:self
						forKeyPath:@"showguide"
						   options:NSKeyValueObservingOptionNew
						   context:NULL];
	[[NSUserDefaults standardUserDefaults] addObserver:self
						forKeyPath:@"guidecolumn"
						   options:NSKeyValueObservingOptionNew
						   context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
		      ofObject:(id)object
			change:(NSDictionary *)change
		       context:(void *)context

{
	ViDocument *doc;

	if ([keyPath isEqualToString:@"theme"]) {
		for (doc in [[NSDocumentController sharedDocumentController] documents])
			[doc changeTheme:[[ViThemeStore defaultStore] themeWithName:[change objectForKey:NSKeyValueChangeNewKey]]];
	} else if ([keyPath isEqualToString:@"showguide"] || [keyPath isEqualToString:@"guidecolumn"]) {
		for (doc in [[NSDocumentController sharedDocumentController] documents])
			[doc updatePageGuide];
	}
}

- (IBAction)showPreferences:(id)sender
{
	[[ViPreferencesController sharedPreferences] show];
}

- (NSMutableDictionary *)sharedBuffers
{
	return sharedBuffers;
}

extern BOOL makeNewWindowInsteadOfTab;

- (IBAction)newProject:(id)sender
{
	makeNewWindowInsteadOfTab = YES;
	[[NSDocumentController sharedDocumentController] newDocument:self];
#if 0
	NSError *error = nil;
	NSDocument *proj = [[NSDocumentController sharedDocumentController] makeUntitledDocumentOfType:@"Project" error:&error];
	INFO(@"proj = %@", proj);
	if (proj)
	{
		[[NSDocumentController sharedDocumentController] addDocument:proj];
		[proj makeWindowControllers];
		[[NSDocumentController sharedDocumentController] newDocument:self];
		[proj showWindows];
	}
	else
		INFO(@"error = %@", error);
#endif
}

- (IBAction)registerLicense:(id)sender
{
	time_t created_at = 0;
	unsigned int serial = 0;
	unsigned int flags = 0;

	const char *key = [[licenseKey stringValue] UTF8String];
	const char *name = [[licenseOwner stringValue] UTF8String];
	const char *email = [[licenseEmail stringValue] UTF8String];

	[[NSUserDefaults standardUserDefaults] setObject:[licenseKey stringValue] forKey:@"licenseKey"];
	[[NSUserDefaults standardUserDefaults] setObject:[licenseOwner stringValue] forKey:@"licenseOwner"];
	[[NSUserDefaults standardUserDefaults] setObject:[licenseEmail stringValue] forKey:@"licenseEmail"];

	if (!check_license_base32(key, &created_at, &serial, &flags))
		NSLog(@"license key not properly formed");
	else
		INFO(@"license key appears ok, serial %u, flags %u, created %s", serial, flags, ctime(&created_at));

	if (!check_license_1(name, email, key, &created_at, &serial, &flags))
		NSLog(@"license key not valid");
	else
		INFO(@"license key valid, serial %u, flags %u, created %s", serial, flags, ctime(&created_at));

	[registrationWindow orderOut:self];
}

- (IBAction)dismissRegistrationWindow:(id)sender
{
	[registrationWindow orderOut:self];
}

@end

