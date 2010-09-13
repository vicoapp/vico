#if 0
# import <Carbon/Carbon.h>
#endif

#import "ViPreferencesController.h"
#import "ViThemeStore.h"
#import "logging.h"

/* this code is from the apple documentation... */
static float
ToolbarHeightForWindow(NSWindow *window)
{
	NSToolbar *toolbar = [window toolbar];
	float toolbarHeight = 0.0;
	NSRect windowFrame;

	if (toolbar && [toolbar isVisible]) {
		windowFrame = [NSWindow contentRectForFrameRect:[window frame]
						      styleMask:[window styleMask]];
		toolbarHeight = NSHeight(windowFrame) - NSHeight([[window contentView] frame]);
	}

	return toolbarHeight;
}

@implementation ViPreferencesController

+ (ViPreferencesController *)sharedPreferences
{
	static ViPreferencesController *sharedPreferencesController = nil;
	if (sharedPreferencesController == nil)
		sharedPreferencesController = [[ViPreferencesController alloc] init];
	return sharedPreferencesController;
}

- (id)init
{
	if ((self = [super initWithWindowNibName:@"PreferenceWindow"])) {
		blankView = [[NSView alloc] init];
	}

	return self;
}

#if 0
- (void)loadInputSources
{
	NSArray  *inputSources = (NSArray *)TISCreateInputSourceList(NULL, false);
	NSMutableDictionary *availableLanguages = [NSMutableDictionary dictionaryWithCapacity:[inputSources count]];
	NSUInteger i;
	TISInputSourceRef chosen, languageRef1, languageRef2;
	for (i = 0; i < [inputSources count]; ++i) {
		[availableLanguages setObject:[inputSources objectAtIndex:i]
				       forKey:TISGetInputSourceProperty((TISInputSourceRef)[inputSources objectAtIndex:i], kTISPropertyLocalizedName)];
	}

	NSString *lang;
	for (lang in availableLanguages) {
		[insertModeInputSources addItemWithTitle:lang];
		[normalModeInputSources addItemWithTitle:lang];
	}
}
#endif

- (void)setSelectedFont
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	[currentFont setStringValue:[NSString stringWithFormat:@"%@ %.1fpt", [defs stringForKey:@"fontname"], [defs floatForKey:@"fontsize"]]];
}

- (void)windowDidLoad
{
	NSString *theme;
	for (theme in [[[ViThemeStore defaultStore] availableThemes] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)])
		[themeButton addItemWithTitle:theme];
	[themeButton selectItem:[themeButton itemWithTitle:[[[ViThemeStore defaultStore] defaultTheme] name]]];

#if 0
	[self loadInputSources];
#endif

	// Load last viewed pane
	[self switchToItem:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastPrefPane"]];

	[[NSUserDefaults standardUserDefaults] addObserver:self
						forKeyPath:@"fontsize"
						   options:NSKeyValueObservingOptionNew
						   context:NULL];
	[[NSUserDefaults standardUserDefaults] addObserver:self
						forKeyPath:@"fontname"
						   options:NSKeyValueObservingOptionNew
						   context:NULL];

	[self setSelectedFont];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
		      ofObject:(id)object
			change:(NSDictionary *)change
		       context:(void *)context

{
	INFO(@"keyPath = %@", keyPath);
	if ([keyPath isEqualToString:@"fontsize"] || [keyPath isEqualToString:@"fontname"])
		[self setSelectedFont];
}

- (void)show
{
	[[self window] makeKeyAndOrderFront:self];
}

- (BOOL)windowShouldClose:(id)sender
{
	[[self window] orderOut:sender];
	return NO;
}

#pragma mark -
#pragma mark Toolbar and preference panes

- (void)resizeWindowToSize:(NSSize)newSize
{
	NSRect aFrame;

	float newHeight = newSize.height + ToolbarHeightForWindow([self window]);
	float newWidth = newSize.width;

	aFrame = [NSWindow contentRectForFrameRect:[[self window] frame]
					 styleMask:[[self window] styleMask]];

	aFrame.origin.y += aFrame.size.height;
	aFrame.origin.y -= newHeight;
	aFrame.size.height = newHeight;
	aFrame.size.width = newWidth;

	aFrame = [NSWindow frameRectForContentRect:aFrame styleMask:[[self window] styleMask]];

	[[self window] setFrame:aFrame display:YES animate:YES];
}

- (void)switchToView:(NSView *)view
{
	NSSize newSize = [view frame].size;

	[[self window] setContentView:blankView];
	[self resizeWindowToSize:newSize];
	[[self window] setContentView:view];
}

- (IBAction)switchToItem:(id)sender
{
	NSView *view = nil;
	NSString *identifier;

	/*
	 * If the call is from a toolbar button, the sender will be an
	 * NSToolbarItem and we will need to fetch its itemIdentifier.
	 * If we want to call this method by hand, we can send it an NSString
	 * which will be used instead.
	 */
	if ([sender respondsToSelector:@selector(itemIdentifier)])
		identifier = [sender itemIdentifier];
	else
		identifier = sender;

	if ([identifier isEqualToString:@"GeneralItem"])
		view = generalView;
	else if ([identifier isEqualToString:@"EditingItem"])
		view = editingView;
	else if ([identifier isEqualToString:@"FontsColorsItem"])
		view = fontsColorsView;

	if (view) {
		[self switchToView:view];
		[[[self window] toolbar] setSelectedItemIdentifier:identifier];
		[[NSUserDefaults standardUserDefaults] setObject:identifier forKey:@"lastPrefPane"];
	}
}

- (IBAction)selectFont:(id)sender
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSFontManager *fontManager = [NSFontManager sharedFontManager];
	NSFont *font = [NSFont fontWithName:[defs stringForKey:@"fontname"] size:[defs floatForKey:@"fontsize"]];
	[fontManager setSelectedFont:font isMultiple:NO];
	[fontManager orderFrontFontPanel:nil];
}

- (void)changeFont:(id)sender
{
	NSFontManager *fontManager = [NSFontManager sharedFontManager];
	NSFont *font = [fontManager convertFont:[fontManager selectedFont]];
	[[NSUserDefaults standardUserDefaults] setObject:[font fontName] forKey:@"fontname"];
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:[font pointSize]] forKey:@"fontsize"];
}

@end

