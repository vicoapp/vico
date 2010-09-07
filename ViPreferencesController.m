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

- (void)windowDidLoad
{
	NSString *theme;
	for (theme in [[[ViThemeStore defaultStore] availableThemes] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)])
		[themeButton addItemWithTitle:theme];
	[themeButton selectItem:[themeButton itemWithTitle:[[[ViThemeStore defaultStore] defaultTheme] name]]];
	
	// Load last viewed pane
	[self switchToItem:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastPrefPane"]];
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
	INFO(@"sender = %@", sender);
}

@end

