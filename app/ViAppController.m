#import "ViAppController.h"
#import "ViThemeStore.h"
#import "ViBundleStore.h"
#import "ViDocument.h"
#import "ViDocumentView.h"
#import "ViDocumentController.h"
#import "ViPreferencesController.h"
#import "ViPreferencePaneGeneral.h"
#import "ViPreferencePaneEdit.h"
#import "ViPreferencePaneTheme.h"
#import "ViPreferencePaneBundles.h"
#import "ViPreferencePaneAdvanced.h"
#import "TMFileURLProtocol.h"
#import "TxmtURLProtocol.h"
#import "JSON.h"
#import "ViError.h"
#import "ViCommandMenuItemView.h"
#import "ViTextView.h"
#import "ViEventManager.h"

#import "ViFileURLHandler.h"
#import "ViSFTPURLHandler.h"
#import "ViHTTPURLHandler.h"

#include <sys/time.h>

@implementation ViAppController

@synthesize encodingMenu;
@synthesize original_input_source;

- (void)getUrl:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
	NSString *s = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];

	NSURL *url = [NSURL URLWithString:s];
	NSError *error = nil;
	[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url
									       display:YES
										 error:&error];
	if (error)
		[NSApp presentError:error];
}

- (id)init
{
	self = [super init];
	if (self) {
		[NSApp setDelegate:self];
		[[NSAppleEventManager sharedAppleEventManager] setEventHandler:self
							  andSelector:@selector(getUrl:withReplyEvent:)
							forEventClass:kInternetEventClass
							   andEventID:kAEGetURL];
	}
	return self;
}

// Application Delegate method
// stops the application from creating an untitled document on load
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	return YES;
}

- (void)newBundleLoaded:(NSNotification *)notification
{
	/* Check if any open documents got a better language available. */
	ViDocument *doc;
	for (doc in [[NSDocumentController sharedDocumentController] documents])
		if ([doc respondsToSelector:@selector(configureSyntax)])
			[doc configureSyntax];
}

+ (NSString *)supportDirectory
{
	static NSString *supportDirectory = nil;
	if (supportDirectory == nil) {
		NSURL *url = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
								    inDomain:NSUserDomainMask
							   appropriateForURL:nil
								      create:YES
								       error:nil];
		supportDirectory = [[url path] stringByAppendingPathComponent:@"Vico"];
	}
	return supportDirectory;
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
#if defined(DEBUG_BUILD)
	[NSApp activateIgnoringOtherApps:YES];
#endif

	original_input_source = TISCopyCurrentKeyboardInputSource();
	DEBUG(@"remembering original input: %@",
	    TISGetInputSourceProperty(original_input_source, kTISPropertyLocalizedName));
	recently_launched = YES;

	[[NSFileManager defaultManager] createDirectoryAtPath:[ViAppController supportDirectory]
				  withIntermediateDirectories:YES
						   attributes:nil
							error:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[ViBundleStore bundlesDirectory]
				  withIntermediateDirectories:NO
						   attributes:nil
							error:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:[[ViAppController supportDirectory] stringByAppendingPathComponent:@"Themes"]
				  withIntermediateDirectories:NO
						   attributes:nil
							error:nil];

	NSUserDefaults *userDefs = [NSUserDefaults standardUserDefaults];

	/* initialize default defaults */
	[userDefs registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
	    [NSNumber numberWithInt:4], @"shiftwidth",
	    [NSNumber numberWithInt:8], @"tabstop",
	    [NSNumber numberWithBool:YES], @"autoindent",
	    [NSNumber numberWithBool:YES], @"smartindent",
	    [NSNumber numberWithBool:YES], @"smartpair",
	    [NSNumber numberWithBool:YES], @"ignorecase",
	    [NSNumber numberWithBool:NO], @"smartcase",
	    [NSNumber numberWithBool:YES], @"expandtab",
	    [NSNumber numberWithBool:YES], @"smarttab",
	    [NSNumber numberWithBool:YES], @"number",
	    [NSNumber numberWithBool:YES], @"autocollapse",
	    [NSNumber numberWithBool:YES], @"hidetab",
	    [NSNumber numberWithBool:YES], @"searchincr",
	    [NSNumber numberWithBool:NO], @"showguide",
	    [NSNumber numberWithBool:YES], @"wrap",
	    [NSNumber numberWithBool:YES], @"antialias",
	    [NSNumber numberWithBool:YES], @"prefertabs",
	    [NSNumber numberWithBool:NO], @"cursorline",
	    [NSNumber numberWithInt:80], @"guidecolumn",
	    [NSNumber numberWithFloat:11.0], @"fontsize",
	    @"vim", @"undostyle",
	    @"Menlo Regular", @"fontname",
	    @"Sunset", @"theme",
	    @"(^\\.|^(CVS|_darcs|\\.svn|\\.git)$|~$|\\.(bak|o|pyc|tar.gz|tgz|zip|dmg|pkg)$)", @"skipPattern",
	    [NSArray arrayWithObjects:
		[NSDictionary dictionaryWithObject:@"vicoapp" forKey:@"username"],
		[NSDictionary dictionaryWithObject:@"textmate" forKey:@"username"],
		[NSDictionary dictionaryWithObject:@"kswedberg" forKey:@"username"],
		nil], @"bundleRepositoryUsers",
	    [NSNumber numberWithBool:YES], @"explorecaseignore",
	    [NSNumber numberWithBool:NO], @"exploresortfolders",
	    @"text.plain", @"defaultsyntax",
	    [NSDictionary dictionaryWithObjectsAndKeys:@"__MyCompanyName__", @"TM_ORGANIZATION_NAME", @"rTbgqR B=.,?_A_a Q=_s>|", @"PARINIT", nil], @"environment",
	    nil]];

	/* Initialize languages and themes. */
	[ViBundleStore defaultStore];
	[ViThemeStore defaultStore];

	NSArray *opts = [NSArray arrayWithObjects:
	    @"theme", @"showguide", @"guidecolumn", @"undostyle", nil];
	for (NSString *opt in opts)
		[userDefs addObserver:self
			   forKeyPath:opt
			      options:NSKeyValueObservingOptionNew
			      context:NULL];

	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(newBundleLoaded:)
	                                             name:ViBundleStoreBundleLoadedNotification
	                                           object:nil];

	const NSStringEncoding *encoding = [NSString availableStringEncodings];
	NSMutableArray *array = [NSMutableArray array];
	NSMenuItem *item;
	while (*encoding) {
		NSString *title = [NSString localizedNameOfStringEncoding:*encoding];
		item = [[NSMenuItem alloc] initWithTitle:title
						  action:@selector(setEncoding:)
					   keyEquivalent:@""];
		[item setRepresentedObject:[NSNumber numberWithUnsignedLong:*encoding]];
		[array addObject:item];
		encoding++;
	}

	[[ViURLManager defaultManager] registerHandler:[[ViFileURLHandler alloc] init]];
	[[ViURLManager defaultManager] registerHandler:[[ViSFTPURLHandler alloc] init]];
	[[ViURLManager defaultManager] registerHandler:[[ViHTTPURLHandler alloc] init]];

	NSSortDescriptor *sdesc = [[NSSortDescriptor alloc] initWithKey:@"title"
	                                                      ascending:YES];
	[array sortUsingDescriptors:[NSArray arrayWithObject:sdesc]];
	for (item in array)
		[encodingMenu addItem:item];

	[TMFileURLProtocol registerProtocol];
	[TxmtURLProtocol registerProtocol];

	shellConn = [NSConnection new];
	[shellConn setRootObject:self];
	[shellConn registerName:[NSString stringWithFormat:@"vico.%u", (unsigned int)getuid()]];

	extern struct timeval launch_start;
	struct timeval launch_done, launch_diff;
	gettimeofday(&launch_done, NULL);
	timersub(&launch_done, &launch_start, &launch_diff);
	INFO(@"launched after %fs", launch_diff.tv_sec + (float)launch_diff.tv_usec / 1000000);

#if defined(SNAPSHOT_BUILD) && defined(EXPIRATION) && EXPIRATION > 0
#warning Enabling time-based expiration of development build
	time_t expire_at = EXPIRATION;
	DEBUG(@"checking expiration date at %s", ctime(&expire_at));
	NSAlert *alert = [[NSAlert alloc] init];
	if (time(NULL) > expire_at) {
		[alert setMessageText:@"This development version has expired."];
		[alert addButtonWithTitle:@"Quit"];
		[alert addButtonWithTitle:@"Download new version"];
		[alert setInformativeText:@"Development versions have a limited validity period for you to test the program. This version has now expired, but you can download a new version for another period."];
		NSUInteger ret = [alert runModal];
		if (ret == NSAlertSecondButtonReturn)
			[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.vicoapp.com/"]];
		exit(7);
	} else if (![userDefs boolForKey:@"devVersionInfoSuppress"]) {
		[alert setMessageText:@"This is a development version."];
		[alert addButtonWithTitle:@"OK"];
		NSString *expireAt = [[NSDate dateWithTimeIntervalSince1970:expire_at] descriptionWithLocale:[NSLocale currentLocale]];
		[alert setInformativeText:[NSString stringWithFormat:@"Development versions have a limited validity period for you to test the program. This version expires at %@. If you want to continue testing after this, you are welcome to download a new version.", expireAt]];
		[alert setShowsSuppressionButton:YES];
		[alert runModal];
		if ([[alert suppressionButton] state] == NSOnState) {
			// Suppress this alert from now on.
			[userDefs setBool:YES forKey:@"devVersionInfoSuppress"];
		}
	}
#endif

	/* Register default preference panes. */
	ViPreferencesController *prefs = [ViPreferencesController sharedPreferences];
	[prefs registerPane:[[ViPreferencePaneGeneral alloc] init]];
	[prefs registerPane:[[ViPreferencePaneEdit alloc] init]];
	[prefs registerPane:[[ViPreferencePaneTheme alloc] init]];
	[prefs registerPane:[[ViPreferencePaneBundles alloc] init]];
	[prefs registerPane:[[ViPreferencePaneAdvanced alloc] init]];

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(beginTrackingMainMenu:)
						     name:NSMenuDidBeginTrackingNotification
						   object:[NSApp mainMenu]];
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(endTrackingMainMenu:)
						     name:NSMenuDidEndTrackingNotification
						   object:[NSApp mainMenu]];

	NSString *siteFile = [[ViAppController supportDirectory] stringByAppendingPathComponent:@"site.nu"];
	NSString *siteScript = [NSString stringWithContentsOfFile:siteFile
							 encoding:NSUTF8StringEncoding
							    error:nil];
	if (siteScript) {
		NSError *error = nil;
		[self eval:siteScript error:&error];
		if (error)
			INFO(@"%@: %@", siteFile, [error localizedDescription]);
	}

	[[ViEventManager defaultManager] emit:ViEventDidFinishLaunching for:nil with:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
		      ofObject:(id)object
			change:(NSDictionary *)change
		       context:(void *)context
{
	ViDocument *doc;

	if ([keyPath isEqualToString:@"theme"]) {
		for (doc in [[NSDocumentController sharedDocumentController] documents])
			if ([doc respondsToSelector:@selector(changeTheme:)])
				[doc changeTheme:[[ViThemeStore defaultStore] themeWithName:[change objectForKey:NSKeyValueChangeNewKey]]];
	} else if ([keyPath isEqualToString:@"showguide"] || [keyPath isEqualToString:@"guidecolumn"]) {
		for (doc in [[NSDocumentController sharedDocumentController] documents])
			if ([doc respondsToSelector:@selector(updatePageGuide)])
				[doc updatePageGuide];
	} else if ([keyPath isEqualToString:@"undostyle"]) {
		NSString *undostyle = [change objectForKey:NSKeyValueChangeNewKey];
		if (![undostyle isEqualToString:@"vim"] && ![undostyle isEqualToString:@"nvi"])
			[[NSUserDefaults standardUserDefaults] setObject:@"vim" forKey:@"undostyle"];
	}
}

- (void)applicationWillResignActive:(NSNotification *)aNotification
{
	TISSelectInputSource(original_input_source);
	DEBUG(@"selecting original input: %@",
	    TISGetInputSourceProperty(original_input_source, kTISPropertyLocalizedName));
	[[ViEventManager defaultManager] emit:ViEventWillResignActive for:nil with:nil];
}

- (void)applicationWillBecomeActive:(NSNotification *)aNotification
{
	if (!recently_launched) {
		original_input_source = TISCopyCurrentKeyboardInputSource();
		DEBUG(@"remembering original input: %@",
		    TISGetInputSourceProperty(original_input_source, kTISPropertyLocalizedName));
	}
	recently_launched = NO;

	ViWindowController *wincon = [ViWindowController currentWindowController];
	id<ViViewController> viewController = [wincon currentView];
	if ([viewController isKindOfClass:[ViDocumentView class]]) {
		[[(ViDocumentView *)viewController textView] resetInputSource];
	}

	[[ViEventManager defaultManager] emit:ViEventDidBecomeActive for:nil with:nil];
}

- (IBAction)showPreferences:(id)sender
{
	[[ViPreferencesController sharedPreferences] show];
}

extern BOOL makeNewWindowInsteadOfTab;

- (IBAction)newProject:(id)sender
{
#if 0
	NSError *error = nil;
	NSDocument *proj = [[NSDocumentController sharedDocumentController] makeUntitledDocumentOfType:@"Project" error:&error];
	if (proj) {
		[[NSDocumentController sharedDocumentController] addDocument:proj];
		[proj makeWindowControllers];
		[proj showWindows];
	}
	else {
		NSAlert *alert = [NSAlert alertWithError:error];
		[alert runModal];
	}
#else
	makeNewWindowInsteadOfTab = YES;
	[[ViDocumentController sharedDocumentController] newDocument:sender];
#endif
}

#pragma mark -
#pragma mark Script evaluation

/* Set some convenient global objects. */
- (void)exportGlobals:(NSMutableDictionary *)context
{
	NuSymbolTable *symbolTable = [NuSymbolTable sharedSymbolTable];

	ViWindowController *winCon = [ViWindowController currentWindowController];
	if (winCon) {
		[context setObject:winCon forKey:[symbolTable symbolWithString:@"window"]];
		[context setObject:winCon.explorer forKey:[symbolTable symbolWithString:@"explorer"]];
		id<ViViewController> view = [winCon currentView];
		if (view) {
			[context setObject:view forKey:[symbolTable symbolWithString:@"view"]];
			if ([view isKindOfClass:[ViDocumentView class]]) {
				ViTextView *textView = [(ViDocumentView *)view textView];
				[context setObject:textView forKey:[symbolTable symbolWithString:@"text"]];
			}
		}
		ViDocument *doc = [winCon currentDocument];
		if (doc)
			[context setObject:doc forKey:[symbolTable symbolWithString:@"document"]];
	}

	[context setObject:[ViEventManager defaultManager] forKey:[symbolTable symbolWithString:@"eventManager"]];
}

- (void)loadStandardModules:(NSMutableDictionary *)context
{
	[Nu loadNuFile:@"nu"            fromBundleWithIdentifier:@"nu.programming.framework" withContext:context];
	[Nu loadNuFile:@"bridgesupport" fromBundleWithIdentifier:@"nu.programming.framework" withContext:context];
	[Nu loadNuFile:@"cocoa"         fromBundleWithIdentifier:@"nu.programming.framework" withContext:context];
	[Nu loadNuFile:@"nibtools"      fromBundleWithIdentifier:@"nu.programming.framework" withContext:context];
	// [Nu loadNuFile:@"cblocks"       fromBundleWithIdentifier:@"nu.programming.framework" withContext:context];
	[Nu loadNuFile:@"vico"          fromBundleWithIdentifier:@"se.bzero.Vico" withContext:context];
}

- (id)eval:(NSString *)script
withParser:(NuParser *)parser
  bindings:(NSDictionary *)bindings
     error:(NSError **)outError
{
	[self exportGlobals:[parser context]];

	DEBUG(@"additional bindings: %@", bindings);
	for (NSString *key in [bindings allKeys])
		if ([key isKindOfClass:[NSString class]])
			[parser setValue:[bindings objectForKey:key] forKey:key];

	DEBUG(@"evaluating script: {{{ %@ }}}", script);

	id result = nil;
	@try {
		id code = [parser parse:script];
		if (code == nil) {
			if (outError)
				*outError = [ViError errorWithFormat:@"parse failed"];
			return nil;
		}

		DEBUG(@"context: %@", [parser context]);
		result = [parser eval:code];
	}
	@catch (NSException *exception) {
		INFO(@"%@: %@", [exception name], [exception reason]);
		if (outError)
			*outError = [ViError errorWithFormat:@"Got exception %@: %@", [exception name], [exception reason]];
		return nil;
	}

	return result;
}

- (id)eval:(NSString *)script
     error:(NSError **)outError
{
	NuParser *parser = [[NuParser alloc] init];
	[self loadStandardModules:[parser context]];
	return [self eval:script withParser:parser bindings:nil error:outError];
}

#pragma mark -
#pragma mark Shell commands

- (NSString *)eval:(NSString *)script
additionalBindings:(NSDictionary *)bindings
       errorString:(NSString **)errorString
       backChannel:(NSString *)channelName
{
	NuParser *parser = [[NuParser alloc] init];
	[self loadStandardModules:[parser context]];

	if (channelName) {
		NSDistantObject *backChannel = [NSConnection rootProxyForConnectionWithRegisteredName:channelName host:nil];
		[parser setValue:backChannel forKey:@"shellCommand"];
	}

	NSError *error = nil;
	id result = [self eval:script withParser:parser bindings:bindings error:&error];
	if (error && errorString)
		*errorString = [error localizedDescription];

	if ([result isKindOfClass:[NSNull class]])
		return nil;
	return [result JSONRepresentation];
}

- (NSError *)openURL:(NSString *)pathOrURL andWait:(BOOL)waitFlag backChannel:(NSString *)channelName
{
	ViDocumentController *docCon = [ViDocumentController sharedDocumentController];

	NSProxy<ViShellThingProtocol> *backChannel = nil;
	if (channelName)
		backChannel = [NSConnection rootProxyForConnectionWithRegisteredName:channelName host:nil];

	NSURL *url;
	if ([pathOrURL isKindOfClass:[NSURL class]])
		url = (NSURL *)pathOrURL;
	else
		url = [[ViURLManager defaultManager] normalizeURL:[[NSURL URLWithString:pathOrURL] absoluteURL]];

	NSError *error = nil;
	ViDocument *doc = [docCon openDocumentWithContentsOfURL:url
							display:YES
							  error:&error];

	if ([doc respondsToSelector:@selector(setCloseCallback:)]) {
		[doc setCloseCallback:^(int code) {
			@try {
				[backChannel exitWithError:code];
			}
			@catch (NSException *exception) {
				INFO(@"failed to notify vicotool: %@", exception);
			}
		}];
	}

	if (doc)
		[NSApp activateIgnoringOtherApps:YES];

	return error;
}

- (NSError *)openURL:(NSString *)pathOrURL
{
	return [self openURL:pathOrURL andWait:NO backChannel:nil];
}

#pragma mark -

- (void)beginTrackingMainMenu:(NSNotification *)notification
{
	menuTrackedKeyWindow = [NSApp keyWindow];
}

- (void)endTrackingMainMenu:(NSNotification *)notification
{
	menuTrackedKeyWindow = nil;
}

/*
 * XXX: this is called on every key event, can we only call it when the menu is shown?
 */
- (void)menuNeedsUpdate:(NSMenu *)menu
{
	ViRegexp *rx = [[ViRegexp alloc] initWithString:@" +\\((.*?)\\)( *\\((.*?)\\))?$"];

	NSWindow *keyWindow = menuTrackedKeyWindow;
	if (keyWindow == nil)
		keyWindow = [NSApp keyWindow];
	ViWindowController *windowController = [keyWindow windowController];
	BOOL isDocWindow = [windowController isKindOfClass:[ViWindowController class]];

	BOOL hasSelection = NO;
	NSWindow *window = [[NSApplication sharedApplication] mainWindow];
	NSResponder *target = [window firstResponder];
	if ([target respondsToSelector:@selector(selectedRange)] &&
	    [(NSText *)target selectedRange].length > 0)
		hasSelection = YES;

	for (NSMenuItem *item in [menu itemArray]) {
		if (item == closeDocumentMenuItem) {
			id<ViViewController> viewController = [[ViWindowController currentWindowController] currentView];
			if (viewController == nil || !isDocWindow)
				[item setTitle:@"Close Document"];
			else
				[item setTitle:[NSString stringWithFormat:@"Close \"%@\"", [viewController title]]];
			continue;
		} else if (item == closeWindowMenuItem) {
			if (isDocWindow)
				[item setKeyEquivalent:@"W"];
			else
				[item setKeyEquivalent:@"w"];
			continue;
		} else if (item == closeTabMenuItem) {
			if (isDocWindow)
				[item setKeyEquivalent:@"w"];
			else
				[item setKeyEquivalent:@""];
			continue;
		} else if (item == showFileExplorerMenuItem) {
			if (isDocWindow && [[windowController explorer] explorerIsOpen])
				[item setTitle:@"Hide File Explorer"];
			else
				[item setTitle:@"Show File Explorer"];
		} else if (item == showSymbolListMenuItem) {
			if (isDocWindow && [[windowController symbolController] symbolListVisible])
				[item setTitle:@"Hide Symbol List"];
			else
				[item setTitle:@"Show Symbol List"];
		}

		if ([item isHidden])
			continue;

		NSString *title = nil;
		if ([item tag] == 4000) {
			title = [item title];
			[item setRepresentedObject:title];
		} else if ([item tag] == 4001)
			title = [item representedObject];

		if (title) {
			DEBUG(@"updating menuitem %@, title %@", item, title);
			ViRegexpMatch *m = [rx matchInString:title];
			if (m && [m count] == 4) {
				NSMutableString *newTitle = [title mutableCopy];
				[newTitle replaceCharactersInRange:[m rangeOfMatchedString]
							withString:@""];
				DEBUG(@"title %@ -> %@, got %lu matches", title, newTitle, [m count]);

				NSRange nrange = [m rangeOfSubstringAtIndex:1];	/* normal range */
				NSRange vrange = [m rangeOfSubstringAtIndex:3]; /* visual range */
				if (vrange.location == NSNotFound)
					vrange = nrange;

				DEBUG(@"nrange = %@, vrange = %@", NSStringFromRange(nrange), NSStringFromRange(vrange));

				DEBUG(@"hasSelection = %s", hasSelection ? "YES" : "NO");

				/* Replace "Thing / Selection" depending on hasSelection.
				 */
				NSRange r = [newTitle rangeOfString:@" / Selection"];
				if (r.location != NSNotFound) {
					if (hasSelection) {
						NSCharacterSet *set = [NSCharacterSet letterCharacterSet];
						NSInteger l;
						for (l = r.location; l > 0; l--)
							if (![set characterIsMember:[newTitle characterAtIndex:l - 1]])
								break;
						NSRange altr = NSMakeRange(l, r.location - l + 3);
						if (altr.length > 3)
							[newTitle deleteCharactersInRange:altr];
					} else
						[newTitle deleteCharactersInRange:r];
				}

				NSString *command = [title substringWithRange:(hasSelection ? vrange : nrange)];
				DEBUG(@"command is [%@]", command);

				if ([command length] == 0) {
					/* use the other match, but disable the menu item */
					command = [title substringWithRange:(hasSelection ? nrange : vrange)];
					DEBUG(@"disabled command is [%@]", command);
					[item setEnabled:NO];
					[item setAction:NULL];
				} else {
					[item setEnabled:YES];
					[item setAction:@selector(performNormalModeMenuItem:)];
				}

				ViCommandMenuItemView *view = (ViCommandMenuItemView *)[item view];
				if (view == nil)
					view = [[ViCommandMenuItemView alloc] initWithTitle:newTitle
										    command:command
										       font:[menu font]];
				else {
					view.title = newTitle;
					view.command = command;
				}
				[item setView:view];
				DEBUG(@"setting title [%@], action is %@", newTitle, NSStringFromSelector([item action]));
				[item setTitle:newTitle];
			}

			[item setTag:4001];	/* mark as already updated */
		}
	}
}

- (IBAction)visitWebsite:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.vicoapp.com/"]];
}

- (IBAction)editSiteScript:(id)sender
{
	NSURL *siteURL = [NSURL fileURLWithPath:[[ViAppController supportDirectory] stringByAppendingPathComponent:@"site.nu"]];
	[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:siteURL display:YES error:nil];
}

@end

