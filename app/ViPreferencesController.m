#import "ViPreferencesController.h"
#import "ViBundleStore.h"
#import "ViAppController.h"

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

- (id<ViPreferencePane>)paneWithName:(NSString *)name
{
	for (id<ViPreferencePane> pane in panes)
		if ([name isEqualToString:[pane name]])
			return pane;
	return nil;
}

- (void)registerPane:(id<ViPreferencePane>)pane
{
	NSString *name = [pane name];
	if ([self paneWithName:name] == nil) {
		[panes addObject:pane];
		NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:name];
		[item setLabel:name];
		[item setTarget:self];
		[item setAction:@selector(switchToItem:)];
		[item setImage:[pane icon]];
		[toolbarItems setObject:item forKey:name];

		[[[self window] toolbar] insertItemWithItemIdentifier:name
							      atIndex:[panes count] - 1];

		NSString *lastPrefPane = [[NSUserDefaults standardUserDefaults]
		    objectForKey:@"lastPrefPane"];
		if ([lastPrefPane isEqualToString:name])
			[self switchToItem:name];
	}
}

- (id)init
{
	if ((self = [super initWithWindowNibName:@"PreferenceWindow"])) {
		blankView = [[NSView alloc] init];
		panes = [NSMutableArray array];
		toolbarItems = [NSMutableDictionary dictionary];
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

- (void)windowDidLoad
{
#if 0
	[self loadInputSources];
#endif

	NSError *error = nil;
	if ([[NSFileManager defaultManager] createDirectoryAtPath:[ViBundleStore bundlesDirectory]
				      withIntermediateDirectories:YES
						       attributes:nil
							    error:&error] == NO) {
		NSAlert *alert = [NSAlert alertWithError:error];
		[alert runModal];
		/* FIXME: continue? disable bundle download? */
	}

	[self setWindowFrameAutosaveName:@"PreferenceWindow"];

	if (forceSwitchToItem)
		[self switchToItem:forceSwitchToItem];
	else {
		/* Load last viewed pane. */
		NSString *lastPrefPane = [[NSUserDefaults standardUserDefaults]
		    objectForKey:@"lastPrefPane"];
		if (lastPrefPane == nil)
			lastPrefPane = @"General";
		[self switchToItem:lastPrefPane];
	}
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
	if (identifier == nil)
		return;

	id<ViPreferencePane> pane = [self paneWithName:identifier];
	view = [pane view];
	if (view == nil || view == [[self window] contentView])
		return;

	[self switchToView:view];
	[[[self window] toolbar] setSelectedItemIdentifier:identifier];
	[[NSUserDefaults standardUserDefaults] setObject:identifier
						  forKey:@"lastPrefPane"];
}

- (void)showItem:(NSString *)item
{
	forceSwitchToItem = item;
	[self show];
	[self switchToItem:item];
}

#pragma mark -
#pragma mark Toolbar delegate methods

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return [toolbarItems allKeys];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar
     itemForItemIdentifier:(NSString *)itemIdentifier
 willBeInsertedIntoToolbar:(BOOL)flag
{
	return [toolbarItems objectForKey:itemIdentifier];
}


@end

