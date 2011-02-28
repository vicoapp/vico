#import "ViPreferencesController.h"
#import "ViLanguageStore.h"
#import "ViThemeStore.h"
#import "ViAppController.h"
#import "logging.h"
#import "JSON.h"

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

@implementation statusIconTransformer
+ (Class)transformedValueClass { return [NSImage class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)init {
	self = [super init];
	installedIcon = [NSImage imageNamed:@"tick"];
	return self;
}
- (id)transformedValue:(id)value
{
	if ([value isEqualToString:@"Installed"])
		return installedIcon;
	return nil;
}
@end

@implementation undoStyleTagTransformer
+ (Class)transformedValueClass { return [NSNumber class]; }
+ (BOOL)allowsReverseTransformation { return YES; }
- (id)init { return [super init]; }
- (id)transformedValue:(id)value
{
	if ([value isKindOfClass:[NSNumber class]]) {
		switch ([value integerValue]) {
		case 2:
			return @"nvi";
		case 1:
		default:
			return @"vim";
		}
	} else if ([value isKindOfClass:[NSString class]]) {
		int tag = 1;
		if ([value isEqualToString:@"nvi"])
			tag = 2;
		return [NSNumber numberWithInt:tag];
	}

	return nil;
}
@end

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
		repositories = [[NSMutableArray alloc] init];
		repoNameRx = [ViRegexp regularExpressionWithString:@"([^[:alnum:]]*tmbundle$)" options:ONIG_OPTION_IGNORECASE];
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

- (NSString *)repoPathForUser:(NSString *)username
{
	return [[NSString stringWithFormat:@"%@/%@-bundles.json", [ViLanguageStore bundlesDirectory], username] stringByExpandingTildeInPath];
}

- (void)updateBundleStatus
{
	NSDate *date = [[NSUserDefaults standardUserDefaults] objectForKey:@"LastBundleRepoReload"];
	if (date) {
		NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
		[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
		[dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
		[bundlesInfo setStringValue:[NSString stringWithFormat:@"%u installed, %u available. Last updated %@.",
		    (unsigned)[[[ViLanguageStore defaultStore] allBundles] count],
		    [repositories count], [dateFormatter stringFromDate:date]]];
	} else {
		[bundlesInfo setStringValue:[NSString stringWithFormat:@"%u installed, %u available.",
		    (unsigned)[[[ViLanguageStore defaultStore] allBundles] count], [repositories count]]];
	}
}

- (void)loadBundlesFromRepo:(NSString *)username
{
	/* Remove any existing repositories owned by this user. */
	[repositories filterUsingPredicate:[NSPredicate predicateWithFormat:@"NOT owner == %@", username]];

	NSData *JSONData = [NSData dataWithContentsOfFile:[self repoPathForUser:username]];
	NSString *JSONString = [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding];
	NSDictionary *dict = [JSONString JSONValue];
	if (![dict isKindOfClass:[NSDictionary class]]) {
		INFO(@"%s", "failed to parse JSON");
		return;
	}

	NSArray *userBundles = [dict objectForKey:@"repositories"];

	/* Remove any non-tmbundle repositories. */
	[repositories addObjectsFromArray:userBundles];
	[repositories filterUsingPredicate:[NSPredicate predicateWithFormat:@"name ENDSWITH \"tmbundle\""]];

	for (NSMutableDictionary *bundle in repositories) {
		NSString *name = [bundle objectForKey:@"name"];
		NSString *status = @"";
		if ([[ViLanguageStore defaultStore] isBundleLoaded:[NSString stringWithFormat:@"%@-%@", [bundle objectForKey:@"owner"], name]])
			status = @"Installed";
		[bundle setObject:status forKey:@"status"];

		/* Set displayName based on name, but trim any trailing .tmbundle. */
		NSString *displayName = [bundle objectForKey:@"name"];
		ViRegexpMatch *m = [repoNameRx matchInString:displayName];
		if (m)
			displayName = [displayName stringByReplacingCharactersInRange:[m rangeOfSubstringAtIndex:1] withString:@""];
		[bundle setObject:[displayName capitalizedString] forKey:@"displayName"];
	}

	[self filterRepositories:repoFilterField];
	[self updateBundleStatus];
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

	[[NSUserDefaults standardUserDefaults] addObserver:self
						forKeyPath:@"fontsize"
						   options:NSKeyValueObservingOptionNew
						   context:NULL];
	[[NSUserDefaults standardUserDefaults] addObserver:self
						forKeyPath:@"fontname"
						   options:NSKeyValueObservingOptionNew
						   context:NULL];

	NSError *error = nil;
	if ([[NSFileManager defaultManager] createDirectoryAtPath:[ViLanguageStore bundlesDirectory]
				      withIntermediateDirectories:YES
						       attributes:nil
							    error:&error] == NO) {
		NSAlert *alert = [NSAlert alertWithError:error];
		[alert runModal];
		/* FIXME: continue? disable bundle download? */
	}

	/* Show an icon in the status column of the repository table. */
	[NSValueTransformer setValueTransformer:[[statusIconTransformer alloc] init] forName:@"statusIconTransformer"];

	/* Convert between tags and undo style strings (vim and nvi). */
	[NSValueTransformer setValueTransformer:[[undoStyleTagTransformer alloc] init] forName:@"undoStyleTagTransformer"];

	/* Sort repositories by installed status, then by name. */
	NSSortDescriptor *statusSort = [[NSSortDescriptor alloc] initWithKey:@"status" ascending:NO];
	NSSortDescriptor *nameSort = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
	[bundlesController setSortDescriptors:[NSArray arrayWithObjects:statusSort, nameSort, nil]];

	NSArray *repoUsers = [[NSUserDefaults standardUserDefaults] arrayForKey:@"bundleRepositoryUsers"];
	for (NSDictionary *repo in repoUsers)
		[self loadBundlesFromRepo:[repo objectForKey:@"username"]];

	[bundlesTable setDoubleAction:@selector(installBundles:)];
	[bundlesTable setTarget:self];

	/* Load last viewed pane. */
	NSString *lastPrefPane = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastPrefPane"];
	if (lastPrefPane == nil)
		lastPrefPane = @"BundlesItem";
	[self switchToItem:lastPrefPane];

	[self setSelectedFont];
	[self setWindowFrameAutosaveName:@"PreferenceWindow"];

	if (forceSwitchToItem )
		[self switchToItem:forceSwitchToItem];
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
#pragma mark Filtering GitHub bundle repositories

- (void)setFilteredRepositories:(NSArray *)anArray
{
	filteredRepositories = anArray;
}

- (IBAction)filterRepositories:(id)sender
{
	NSString *filter = [sender stringValue];
	if ([filter length] == 0) {
		[self setFilteredRepositories:repositories];
		return;
	}

	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(name CONTAINS[cd] %@) OR (description CONTAINS[cd] %@)", filter, filter];
	[self setFilteredRepositories:[repositories filteredArrayUsingPredicate:predicate]];
}

#pragma mark -
#pragma mark Managing GitHub repository users

- (void)selectRepoSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
}

- (IBAction)acceptSelectRepoSheet:(id)sender
{
	[NSApp endSheet:selectRepoSheet];

	/* Remove repositories for any deleted users. */
	for (NSDictionary *prevUser in previousRepoUsers) {
		NSString *prevOwner = [prevUser objectForKey:@"username"];
		BOOL found = NO;
		for (NSDictionary *repoUser in [repoUsersController arrangedObjects]) {
			if ([[repoUser objectForKey:@"username"] isEqualToString:prevOwner]) {
				found = YES;
				break;
			}
		}
		if (!found) {
			[repositories filterUsingPredicate:[NSPredicate predicateWithFormat:@"NOT owner == %@", prevOwner]];
			[self filterRepositories:repoFilterField];
		}
	}

	/* Reload repositories for any added users. */
	NSMutableArray *newUsers = [[NSMutableArray alloc] init];
	for (NSDictionary *repoUser in [repoUsersController arrangedObjects]) {
		BOOL found = NO;
		for (NSDictionary *prevUser in previousRepoUsers) {
			if ([[repoUser objectForKey:@"username"] isEqualToString:[prevUser objectForKey:@"username"]]) {
				found = YES;
				break;
			}
		}
		if (!found)
			[newUsers addObject:repoUser];
	}
	[self reloadRepositoriesFromUsers:newUsers];
}

- (IBAction)selectRepositories:(id)sender
{
	previousRepoUsers = [[repoUsersController arrangedObjects] copy];
	[NSApp beginSheet:selectRepoSheet
	   modalForWindow:[self window]
	    modalDelegate:self
	   didEndSelector:@selector(selectRepoSheetDidEnd:returnCode:contextInfo:)
	      contextInfo:nil];
}

- (IBAction)addRepoUser:(id)sender
{
	NSUInteger row = [[repoUsersController arrangedObjects] count];
	NSMutableDictionary *item = [NSMutableDictionary dictionaryWithObject:[NSMutableString string] forKey:@"username"];
	[repoUsersController insertObject:item atArrangedObjectIndex:row];
	[repoUsersTable selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	[repoUsersTable editColumn:0 row:row withEvent:nil select:YES];
}

#pragma mark -
#pragma mark Downloading GitHub repositories

- (void)progressSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	progressCancelled = NO;
}

- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error
{
	[self cancelProgressSheet:nil];
	NSDictionary *repoUser = [processQueue lastObject];
	[progressDescription setStringValue:[NSString stringWithFormat:@"Failed to load %@'s repository: %@",
	    [repoUser objectForKey:@"username"], [error localizedDescription]]];
}

- (void)downloadDidFinish:(NSURLDownload *)download
{
	NSDictionary *repoUser = [processQueue lastObject];
	[self loadBundlesFromRepo:[repoUser objectForKey:@"username"]];
	[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"LastBundleRepoReload"];

	[processQueue removeLastObject];
	if ([processQueue count] == 0)
		[NSApp endSheet:progressSheet];
	else
		[self reloadNextUser];
}

- (void)setExpectedContentLengthFromResponse:(NSURLResponse *)response
{
	long long expectedContentLength = [response expectedContentLength];
	if (expectedContentLength != NSURLResponseUnknownLength && expectedContentLength > 0) {
		[progressIndicator setIndeterminate:NO];
		[progressIndicator setMaxValue:expectedContentLength];
		[progressIndicator setDoubleValue:receivedContentLength];
	}
}

- (void)resetProgressIndicator
{
	receivedContentLength = 0;
	[progressButton setTitle:@"Cancel"];
	[progressButton setKeyEquivalent:@""];
	[progressIndicator setIndeterminate:YES];
	[progressIndicator startAnimation:self];
	installConnection = nil;
	repoDownload = nil;
}

- (void)download:(NSURLDownload *)download didReceiveResponse:(NSURLResponse *)response
{
	[self setExpectedContentLengthFromResponse:response];
}

- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length
{
	receivedContentLength += length;
	[progressIndicator setDoubleValue:receivedContentLength];
}

- (IBAction)cancelProgressSheet:(id)sender
{
	if (progressCancelled) {
		[NSApp endSheet:progressSheet];
		return;
	}

	/* This action is connected to both repo downloads and bundle installation. */
	if (installConnection) {
		[installConnection cancel];
		[installTask terminate];
		installConnection = nil;
	} else if (userConnection) {
		[userConnection cancel];
		userConnection = nil;
	} else {
		[repoDownload cancel];
		repoDownload = nil;
	}

	progressCancelled = YES;
	[progressButton setTitle:@"OK"];
	[progressButton setKeyEquivalent:@"\r"];
	[progressIndicator stopAnimation:self];
	[progressDescription setStringValue:@"Cancelled download from GitHub"];
}

- (void)reloadNextUser
{
	NSDictionary *repo = [processQueue lastObject];
	NSString *username = [repo objectForKey:@"username"];
	if ([username length] == 0) {
		[processQueue removeLastObject];
		if ([processQueue count] == 0)
			[NSApp endSheet:progressSheet];
		else
			[self reloadNextUser];
	}

	[self resetProgressIndicator];
	[progressDescription setStringValue:[NSString stringWithFormat:@"Loading user %@...", username]];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://github.com/api/v2/json/user/show/%@", username]];
	userConnection = [NSURLConnection connectionWithRequest:[NSURLRequest requestWithURL:url] delegate:self];
	userData = [[NSMutableData alloc] init];
	installConnection = nil;
}

- (void)reloadRepositoriesFromUsers:(NSArray *)users
{
	if ([users count] == 0)
		return;

	[progressDescription setStringValue:@"Loading bundle repositories from GitHub..."];
	[NSApp beginSheet:progressSheet
	   modalForWindow:[self window]
	    modalDelegate:self
	   didEndSelector:@selector(progressSheetDidEnd:returnCode:contextInfo:)
	      contextInfo:nil];

	processQueue = [NSMutableArray arrayWithArray:users];
	[self reloadNextUser];
}

- (IBAction)reloadRepositories:(id)sender
{
	[self reloadRepositoriesFromUsers:[repoUsersController arrangedObjects]];
}

#pragma mark -
#pragma mark Installing bundles from GitHub

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	[self cancelProgressSheet:nil];
	NSMutableDictionary *repo = [processQueue lastObject];
	if (connection == installConnection) {
		[progressDescription setStringValue:[NSString stringWithFormat:@"Download of %@ failed: %@", [repo objectForKey:@"displayName"], [error localizedDescription]]];
		[installTask terminate];
	} else if (connection == userConnection) {
		[progressDescription setStringValue:[NSString stringWithFormat:@"Download of %@ failed: %@", [repo objectForKey:@"username"], [error localizedDescription]]];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	receivedContentLength += [data length];
	if (connection == installConnection) {
		[progressIndicator setDoubleValue:receivedContentLength];
		@try {
			[[installPipe fileHandleForWriting] writeData:data];
		}
		@catch (NSException *exception) {
			[installConnection cancel];
			[installTask terminate];
	
			[self cancelProgressSheet:nil];
			NSMutableDictionary *repo = [processQueue lastObject];
			[progressDescription setStringValue:[NSString stringWithFormat:@"Installation of %@ failed when unpacking.", [repo objectForKey:@"displayName"]]];
		}
	} else if (connection == userConnection) {
		[userData appendData:data];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	if (connection == installConnection)
		[self setExpectedContentLengthFromResponse:response];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	if (connection == userConnection) {
		NSMutableDictionary *repo = [processQueue lastObject];
		NSString *username = [repo objectForKey:@"username"];
	
		NSString *JSONString = [[NSString alloc] initWithData:userData encoding:NSUTF8StringEncoding];
		NSDictionary *dict = [JSONString JSONValue];
		if (![dict isKindOfClass:[NSDictionary class]]) {
			[self cancelProgressSheet:nil];
			[progressDescription setStringValue:[NSString stringWithFormat:@"Failed to parse data for user %@.", username]];
			return;
		}

		INFO(@"got user %@: %@", username, dict);

		[progressDescription setStringValue:[NSString stringWithFormat:@"Loading repositories from %@...", username]];
		NSURL *url;
		NSString *type = [[dict objectForKey:@"user"] objectForKey:@"type"];
		if ([type isEqualToString:@"User"])
			url = [NSURL URLWithString:[NSString stringWithFormat:@"http://github.com/api/v2/json/repos/show/%@", username]];
		else if ([type isEqualToString:@"Organization"])
			url = [NSURL URLWithString:[NSString stringWithFormat:@"http://github.com/api/v2/json/organizations/%@/public_repositories", username]];
		else {
			[self cancelProgressSheet:nil];
			[progressDescription setStringValue:[NSString stringWithFormat:@"Unknown type %@ of user %@", type, username]];
			return;
		}

		INFO(@"loading repositories from %@", url);
		repoDownload = [[NSURLDownload alloc] initWithRequest:[NSURLRequest requestWithURL:url] delegate:self];
		[repoDownload setDestination:[self repoPathForUser:username] allowOverwrite:YES];
		return;
	}

	[[installPipe fileHandleForWriting] closeFile];

	[installTask waitUntilExit];
	int status = [installTask terminationStatus];
	[progressIndicator setIndeterminate:YES];

	NSMutableDictionary *repo = [processQueue lastObject];
	NSString *owner = [repo objectForKey:@"owner"];
	NSString *name = [repo objectForKey:@"name"];
	NSString *displayName = [repo objectForKey:@"displayName"];

	if (status == 0) {
		NSError *error = nil;
		NSString *downloadDirectory = [[ViLanguageStore bundlesDirectory] stringByAppendingPathComponent:@"download"];
		NSString *prefix = [NSString stringWithFormat:@"%@-%@", owner, name];
		NSString *bundleDirectory = nil;
		NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:downloadDirectory error:NULL];
		for (NSString *filename in contents) {
			if ([filename hasPrefix:prefix]) {
				bundleDirectory = filename;
				break;
			}
		}

		if (bundleDirectory == nil) {
			[self cancelProgressSheet:nil];
			[progressDescription setStringValue:[NSString stringWithFormat:@"Installation of %@ failed: downloaded bundle not found", displayName]];
			return;
		}

		contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[ViLanguageStore bundlesDirectory] error:NULL];
		for (NSString *filename in contents) {
			if ([filename hasPrefix:prefix]) {
				NSString *path = [[ViLanguageStore bundlesDirectory] stringByAppendingPathComponent:filename];
				if (![[NSFileManager defaultManager] removeItemAtPath:path error:&error]) {
					[self cancelProgressSheet:nil];
					[progressDescription setStringValue:[NSString stringWithFormat:@"Installation of %@ failed: %@ (%li)",
					    displayName, [error localizedDescription], [error code]]];
					return;
				}
				break;
			}
		}

		/*
		 * Move the bundle from the download directory to the bundles directory.
		 */
		NSString *src = [downloadDirectory stringByAppendingPathComponent:bundleDirectory];
		NSString *dst = [[ViLanguageStore bundlesDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@", owner, name]];
		if (![[NSFileManager defaultManager] moveItemAtPath:src toPath:dst error:&error])  {
			[self cancelProgressSheet:nil];
			[progressDescription setStringValue:[NSString stringWithFormat:@"Installation of %@ failed: %@",
			    displayName, [error localizedDescription]]];
		}

		if ([[ViLanguageStore defaultStore] loadBundleFromDirectory:dst])
			[repo setObject:@"Installed" forKey:@"status"];
		[self updateBundleStatus];
	} else {
		[self cancelProgressSheet:nil];
		[progressDescription setStringValue:[NSString stringWithFormat:@"Installation of %@ failed when unpacking (status %d).",
		    displayName, status]];
		return;
	}

	[processQueue removeLastObject];
	if ([processQueue count] == 0)
		[NSApp endSheet:progressSheet];
	else
		[self installNextBundle];
}

- (void)installNextBundle
{
	NSMutableDictionary *repo = [processQueue lastObject];

	[self resetProgressIndicator];
	[progressDescription setStringValue:[NSString stringWithFormat:@"Downloading and installing %@ (by %@)...",
	    [repo objectForKey:@"name"], [repo objectForKey:@"owner"]]];

	/*
	 * Move away any existing (temporary) bundle directory.
	 */
	NSError *error = nil;
	NSString *downloadDirectory = [[ViLanguageStore bundlesDirectory] stringByAppendingPathComponent:@"download"];
	if (![[NSFileManager defaultManager] removeItemAtPath:downloadDirectory error:&error] && [error code] != NSFileNoSuchFileError) {
		[self cancelProgressSheet:nil];
		[progressDescription setStringValue:[NSString stringWithFormat:@"Installation of %@ failed: %@",
		    [repo objectForKey:@"displayName"], [error localizedDescription]]];
		return;
	}

	if (![[NSFileManager defaultManager] createDirectoryAtPath:downloadDirectory withIntermediateDirectories:YES attributes:nil error:&error]) {
		[self cancelProgressSheet:nil];
		[progressDescription setStringValue:[NSString stringWithFormat:@"Installation of %@ failed: %@",
		    [repo objectForKey:@"displayName"], [error localizedDescription]]];
		return;
	}

	installTask = [[NSTask alloc] init];
	[installTask setLaunchPath:@"/usr/bin/tar"];
	[installTask setArguments:[NSArray arrayWithObjects:@"-x", @"-C", downloadDirectory, nil]];

	installPipe = [NSPipe pipe];
	[installTask setStandardInput:installPipe];

	@try {
		[installTask launch];
	}
	@catch (NSException *exception) {
		[self cancelProgressSheet:nil];
		[progressDescription setStringValue:[NSString stringWithFormat:@"Installation of %@ failed: %@",
		    [repo objectForKey:@"displayName"], [exception reason]]];
		return;
	}

	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/tarball/master", [repo objectForKey:@"url"]]];
	installConnection = [NSURLConnection connectionWithRequest:[NSURLRequest requestWithURL:url] delegate:self];
}

- (IBAction)installBundles:(id)sender
{
	NSArray *selectedBundles = [bundlesController selectedObjects];
	if ([selectedBundles count] == 0)
		return;

	[NSApp beginSheet:progressSheet
	   modalForWindow:[self window]
	    modalDelegate:self
	   didEndSelector:@selector(progressSheetDidEnd:returnCode:contextInfo:)
	      contextInfo:nil];

	processQueue = [NSMutableArray arrayWithArray:selectedBundles];
	[self installNextBundle];
}

- (IBAction)uninstallBundles:(id)sender
{
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
	else if ([identifier isEqualToString:@"BundlesItem"])
		view = bundlesView;

	if (view) {
		if (view == [[self window] contentView])
			return;

		[self switchToView:view];
		[[[self window] toolbar] setSelectedItemIdentifier:identifier];
		[[NSUserDefaults standardUserDefaults] setObject:identifier forKey:@"lastPrefPane"];
	}

	if (view == bundlesView && [repositories count] == 0)
		[self performSelector:@selector(reloadRepositories:) withObject:self afterDelay:0.0];
}

- (void)showItem:(NSString *)item
{
	forceSwitchToItem = item;
	[self show];
	[self switchToItem:item];
}

#pragma mark -
#pragma mark Font selection

- (void)setSelectedFont
{
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	[currentFont setStringValue:[NSString stringWithFormat:@"%@ %.1fpt", [defs stringForKey:@"fontname"], [defs floatForKey:@"fontsize"]]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
		      ofObject:(id)object
			change:(NSDictionary *)change
		       context:(void *)context
{
	if ([keyPath isEqualToString:@"fontsize"] || [keyPath isEqualToString:@"fontname"])
		[self setSelectedFont];
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

