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
#import "ViEventManager.h"
#import "ViFileExplorer.h"
#import "ViMarkInspector.h"
#import "NSMenu-additions.h"

#import "ViFileURLHandler.h"
#import "ViSFTPURLHandler.h"
#import "ViHTTPURLHandler.h"

#include <sys/time.h>

@interface caretBlinkModeTransformer : NSValueTransformer
{
}
@end

@implementation caretBlinkModeTransformer
+ (Class)transformedValueClass { return [NSString class]; }
+ (BOOL)allowsReverseTransformation { return YES; }
- (id)init { return [super init]; }
- (id)transformedValue:(id)value
{
	if ([value isKindOfClass:[NSNumber class]]) {
		switch ([value intValue]) {
		case ViInsertMode:
			return @"insert";
		case ViNormalMode | ViVisualMode:
			return @"normal";
		case ViInsertMode | ViNormalMode | ViVisualMode:
			return @"both";
		default:
			return @"none";
		}
	} else if ([value isKindOfClass:[NSString class]]) {
		if ([value isEqualToString:@"insert"])
			return [NSNumber numberWithInt:ViInsertMode];
		else if ([value isEqualToString:@"normal"])
			return [NSNumber numberWithInt:ViNormalMode | ViVisualMode];
		else if ([value isEqualToString:@"both"])
			return [NSNumber numberWithInt:ViInsertMode | ViNormalMode | ViVisualMode];
		else
			return [NSNumber numberWithInt:0];
	}

	return nil;
}
@end

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

		[NSValueTransformer setValueTransformer:[[[caretBlinkModeTransformer alloc] init] autorelease]
						forName:@"caretBlinkModeTransformer"];
	}
	return self;
}

- (void)dealloc
{
	[_fieldEditor release];
	[super dealloc];
}

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
	static NSString *__supportDirectory = nil;
	if (__supportDirectory == nil) {
		NSURL *url = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
								    inDomain:NSUserDomainMask
							   appropriateForURL:nil
								      create:YES
								       error:nil];
		__supportDirectory = [[[url path] stringByAppendingPathComponent:@"Vico"] retain];
	}
	return __supportDirectory;
}

#ifdef TRIAL_VERSION
#include <openssl/md5.h>
int
updateMeta(void)
{
	NSUserDefaults *userDefs = [NSUserDefaults standardUserDefaults];

	int left = 0;
	time_t last = 0;
	id daysLeft = [userDefs objectForKey:@"left"];
	id lastDayUsed = [userDefs objectForKey:@"last"];
	NSData *hash = [userDefs dataForKey:@"meta"];
	time_t now = time(NULL);

	if (daysLeft == nil || lastDayUsed == nil || hash == nil) {
		if (daysLeft == nil && lastDayUsed == nil && hash == nil) {
			/*
			 * This is the first run.
			 */
			left = 16;
		}
	} else if (![daysLeft respondsToSelector:@selector(intValue)] ||
		   ![lastDayUsed respondsToSelector:@selector(integerValue)] ||
		    [hash length] != MD5_DIGEST_LENGTH) {
		/* Weird value. */
		left = 0;
	} else {
		left = [daysLeft intValue];
		last = [lastDayUsed integerValue] + 1311334235;
		if (left < 0 || left > 15 || last < 0 /*|| last + 3600*2 > now*/) {
			/* Weird value. */
			left = 0;
		} else {
			MD5_CTX ctx;
			bzero(&ctx, sizeof(ctx));
			MD5_Init(&ctx);
			MD5_Update(&ctx, &left, sizeof(left));
			MD5_Update(&ctx, &last, sizeof(last));
			uint8_t md[MD5_DIGEST_LENGTH];
			MD5_Final(md, &ctx);
			if (bcmp(md, [hash bytes], MD5_DIGEST_LENGTH) != 0) {
				/* Hash does NOT correspond to the value. */
				left = 0;
			}
		}
	}

	if (left > 0) {
		struct tm tm_last, tm_now;
		localtime_r(&last, &tm_last);
		localtime_r(&now, &tm_now);
		if (tm_last.tm_yday != tm_now.tm_yday || tm_last.tm_year != tm_now.tm_year) {
			--left;
			[userDefs setInteger:left forKey:@"left"];
			[userDefs setInteger:now - 1311334235 forKey:@"last"];
			MD5_CTX ctx;
			bzero(&ctx, sizeof(ctx));
			MD5_Init(&ctx);
			MD5_Update(&ctx, &left, sizeof(left));
			MD5_Update(&ctx, &now, sizeof(now));
			uint8_t md[MD5_DIGEST_LENGTH];
			MD5_Final(md, &ctx);
			[userDefs setObject:[NSData dataWithBytes:md length:MD5_DIGEST_LENGTH]
				     forKey:@"meta"];
		}
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:ViTrialDaysChangedNotification
							    object:[NSNumber numberWithInt:left]];

	return left;
}
#endif

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	/* Cache the default IBeam cursor implementation. */
	[NSCursor defaultIBeamCursorImplementation];

	[Nu loadNuFile:@"vico" fromBundleWithIdentifier:@"se.bzero.Vico" withContext:nil];
	[Nu loadNuFile:@"keys" fromBundleWithIdentifier:@"se.bzero.Vico" withContext:nil];
	[Nu loadNuFile:@"ex"   fromBundleWithIdentifier:@"se.bzero.Vico" withContext:nil];

#if defined(DEBUG_BUILD)
	[NSApp activateIgnoringOtherApps:YES];
#endif

	original_input_source = TISCopyCurrentKeyboardInputSource();
	DEBUG(@"remembering original input: %@",
	    TISGetInputSourceProperty(original_input_source, kTISPropertyLocalizedName));
	_recently_launched = YES;

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
	    [NSNumber numberWithBool:NO], @"gdefault",
	    [NSNumber numberWithBool:YES], @"wrapscan",
	    [NSNumber numberWithBool:NO], @"clipboard",
	    [NSNumber numberWithBool:YES], @"matchparen",
	    [NSNumber numberWithBool:NO], @"flashparen",
	    [NSNumber numberWithBool:YES], @"linebreak",
	    [NSNumber numberWithInt:80], @"guidecolumn",
	    [NSNumber numberWithFloat:12.0], @"fontsize",
	    [NSNumber numberWithFloat:0.75], @"blinktime",
	    @"none", @"blinkmode",
	    @"Monaco", @"fontname",
	    @"vim", @"undostyle",
	    @"Sunset", @"theme",
	    @"(^\\.(?!(htaccess|(git|hg|cvs)ignore)$)|^(CVS|_darcs|\\.svn|\\.git)$|~$|\\.(bak|o|pyc|gz|tgz|zip|dmg|pkg)$)", @"skipPattern",
	    [NSArray arrayWithObjects:@"vicoapp", @"textmate", @"kswedberg", nil], @"bundleRepoUsers",
	    [NSNumber numberWithBool:YES], @"explorecaseignore",
	    [NSNumber numberWithBool:NO], @"exploresortfolders",
	    @"text.plain", @"defaultsyntax",
	    [NSDictionary dictionaryWithObjectsAndKeys:
		@"__MyCompanyName__", @"TM_ORGANIZATION_NAME",
		@"rTbgqR B=.,?_A_a Q=#/_s>|;", @"PARINIT",
		nil], @"environment",
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
		[item release];
		encoding++;
	}

	[[ViURLManager defaultManager] registerHandler:[[[ViFileURLHandler alloc] init] autorelease]];
	[[ViURLManager defaultManager] registerHandler:[[[ViSFTPURLHandler alloc] init] autorelease]];
	[[ViURLManager defaultManager] registerHandler:[[[ViHTTPURLHandler alloc] init] autorelease]];

	NSSortDescriptor *sdesc = [[[NSSortDescriptor alloc] initWithKey:@"title"
	                                                       ascending:YES] autorelease];
	[array sortUsingDescriptors:[NSArray arrayWithObject:sdesc]];
	for (item in array)
		[encodingMenu addItem:item];

	[self forceUpdateMenu:[NSApp mainMenu]];

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

#ifdef TRIAL_VERSION
#warning Enabling used-time-based expiration of trial version
	NSAlert *alert = [[NSAlert alloc] init];
	int left = updateMeta();
	if (left <= 0) {
		[alert setMessageText:@"This trial version has expired."];
		[alert addButtonWithTitle:@"OK"];
		[alert setInformativeText:@"Evaluation is now limited to 15 minutes."];
		NSUInteger ret = [alert runModal];
		[NSTimer scheduledTimerWithTimeInterval:15*60
						 target:self
					       selector:@selector(m:)
					       userInfo:nil
						repeats:NO];
	} else {
		[alert setMessageText:@"This is a trial version."];
		[alert addButtonWithTitle:@"Try Vico"];
		[alert addButtonWithTitle:@"Buy Vico"];
		[alert setInformativeText:[NSString stringWithFormat:@"Vico will expire after %i day%s of use.", left, left == 1 ? "" : "s"]];
		NSUInteger ret = [alert runModal];
		if (ret == NSAlertSecondButtonReturn)
			[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://itunes.com/mac/vico"]];
		mTimer = [NSTimer scheduledTimerWithTimeInterval:1*60
							  target:self
							selector:@selector(m:)
							userInfo:nil
							 repeats:YES];
	}
#endif

	/* Register default preference panes. */
	ViPreferencesController *prefs = [ViPreferencesController sharedPreferences];
	[prefs registerPane:[[[ViPreferencePaneGeneral alloc] init] autorelease]];
	[prefs registerPane:[[[ViPreferencePaneEdit alloc] init] autorelease]];
	[prefs registerPane:[[[ViPreferencePaneTheme alloc] init] autorelease]];
	[prefs registerPane:[[[ViPreferencePaneBundles alloc] init] autorelease]];
	[prefs registerPane:[[[ViPreferencePaneAdvanced alloc] init] autorelease]];

	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(beginTrackingMainMenu:)
						     name:NSMenuDidBeginTrackingNotification
						   object:[NSApp mainMenu]];
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(endTrackingMainMenu:)
						     name:NSMenuDidEndTrackingNotification
						   object:[NSApp mainMenu]];

	NSWindow *dummyWindow = [[NSWindow alloc] initWithContentRect:NSZeroRect styleMask:0 backing:0 defer:YES];
	if ([dummyWindow respondsToSelector:@selector(toggleFullScreen:)]) {
		[viewMenu addItem:[NSMenuItem separatorItem]];
		NSMenuItem *item = [viewMenu addItemWithTitle:@"Enter Full Screen" action:@selector(toggleFullScreen:) keyEquivalent:@"f"];
		[item setKeyEquivalentModifierMask:NSCommandKeyMask | NSControlKeyMask];
	}

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

#ifdef TRIAL_VERSION
- (void)m:(NSTimer *)timer
{
	int left = updateMeta();
	if (left <= 0) {
		NSAlert *alert = [[NSAlert alloc] init];
		[alert setMessageText:@"This trial version has expired."];
		[alert addButtonWithTitle:@"Buy Vico"];
		[alert addButtonWithTitle:@"Quit"];
		NSUInteger ret = [alert runModal];
		if (ret == NSAlertFirstButtonReturn)
			[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://itunes.com/mac/vico"]];

		[NSApp terminate:nil];
		if (mTimer == nil)
			mTimer = [NSTimer scheduledTimerWithTimeInterval:1*60
								  target:self
								selector:@selector(m:)
								userInfo:nil
								 repeats:YES];
	}
}
#endif

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
	ViWindowController *wincon = [ViWindowController currentWindowController];
	id<ViViewController> viewController = [wincon currentView];
	if ([viewController isKindOfClass:[ViDocumentView class]])
		[[(ViDocumentView *)viewController textView] rememberNormalModeInputSource];

		TISSelectInputSource(original_input_source);
	DEBUG(@"selecting original input: %@",
	    TISGetInputSourceProperty(original_input_source, kTISPropertyLocalizedName));
	[[ViEventManager defaultManager] emit:ViEventWillResignActive for:nil with:nil];
}

- (void)applicationWillBecomeActive:(NSNotification *)aNotification
{
	if (!_recently_launched) {
		original_input_source = TISCopyCurrentKeyboardInputSource();
		DEBUG(@"remembering original input: %@",
		    TISGetInputSourceProperty(original_input_source, kTISPropertyLocalizedName));
	}
	_recently_launched = NO;

	ViWindowController *wincon = [ViWindowController currentWindowController];
	id<ViViewController> viewController = [wincon currentView];
	if ([viewController isKindOfClass:[ViDocumentView class]]) {
		[[(ViDocumentView *)viewController textView] resetInputSource];
	}

	[[ViEventManager defaultManager] emit:ViEventDidBecomeActive for:nil with:nil];
}

#pragma mark -
#pragma mark Interface actions

- (IBAction)showPreferences:(id)sender
{
	[[ViPreferencesController sharedPreferences] show];
}

- (IBAction)showMarkInspector:(id)sender
{
	[[ViMarkInspector sharedInspector] show];
}

extern BOOL __makeNewWindowInsteadOfTab;

- (IBAction)newProject:(id)sender
{
	__makeNewWindowInsteadOfTab = YES;
	[[ViDocumentController sharedDocumentController] newDocument:sender];
}

- (IBAction)installTerminalHelper:(id)sender
{
	NSString *locBookName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleHelpBookName"];
	[[NSHelpManager sharedHelpManager] openHelpAnchor:@"terminalUsage" inBook:locBookName];
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

#pragma mark -
#pragma mark Script evaluation

- (id)eval:(NSString *)script
withParser:(NuParser *)parser
  bindings:(NSDictionary *)bindings
     error:(NSError **)outError
{
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
	NuParser *parser = [[[NuParser alloc] init] autorelease];
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

	if (channelName) {
		NSDistantObject *backChannel = [NSConnection rootProxyForConnectionWithRegisteredName:channelName host:nil];
		[parser setValue:backChannel forKey:@"shellCommand"];
	}

	NSError *error = nil;
	id result = [self eval:script withParser:parser bindings:bindings error:&error];
	if (error && errorString)
		*errorString = [error localizedDescription];
	[parser release];

	if ([result isKindOfClass:[NSNull class]])
		return nil;
	return [result JSONRepresentation];
}

- (NSError *)openURL:(NSString *)pathOrURL andWait:(BOOL)waitFlag backChannel:(NSString *)channelName
{
	ViDocumentController *docCon = [ViDocumentController sharedDocumentController];

	NSProxy<ViShellThingProtocol> *backChannel = nil;
	if (channelName)
		backChannel = (NSProxy<ViShellThingProtocol> *)[NSConnection rootProxyForConnectionWithRegisteredName:channelName host:nil];

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
#pragma mark Updating normal mode menu items

- (void)beginTrackingMainMenu:(NSNotification *)notification
{
	_menuTrackedKeyWindow = [[NSApp keyWindow] retain];
	_trackingMainMenu = YES;
}

- (void)endTrackingMainMenu:(NSNotification *)notification
{
	[_menuTrackedKeyWindow release];
	_menuTrackedKeyWindow = nil;
	_trackingMainMenu = NO;
}

- (NSWindow *)keyWindowBeforeMainMenuTracking
{
	return _menuTrackedKeyWindow ?: [NSApp keyWindow];
}

- (void)menuNeedsUpdate:(NSMenu *)menu
{
	NSWindow *keyWindow = [self keyWindowBeforeMainMenuTracking];
	ViWindowController *windowController = [keyWindow windowController];
	BOOL isDocWindow = [windowController isKindOfClass:[ViWindowController class]];

	/*
	 * Revert cmd-w to its original behaviour for non-document windows.
	 */
	if (isDocWindow) {
		[closeWindowMenuItem setKeyEquivalent:@"W"];
		[closeTabMenuItem setKeyEquivalent:@"w"];
		[closeDocumentMenuItem setKeyEquivalent:@"w"];
	} else {
		[closeWindowMenuItem setKeyEquivalent:@"w"];
		[closeTabMenuItem setKeyEquivalent:@""];
		[closeDocumentMenuItem setKeyEquivalent:@""];
	}

	/*
	 * Insert the current document in the title for "Close Document".
	 */
	id<ViViewController> viewController = [[ViWindowController currentWindowController] currentView];
	if (viewController == nil || !isDocWindow)
		[closeDocumentMenuItem setTitle:@"Close Document"];
	else
		[closeDocumentMenuItem setTitle:[NSString stringWithFormat:@"Close \"%@\"", [viewController title]]];

	/*
	 * If we're not tracking the main menu, but got triggered by a
	 * key event, don't update displayed menu items.
	 */
	if (!_trackingMainMenu)
		return;

	/* Do we have a selection? */
	BOOL hasSelection = NO;
	NSWindow *window = [[NSApplication sharedApplication] mainWindow];
	NSResponder *target = [window firstResponder];
	if ([target respondsToSelector:@selector(selectedRange)] &&
	    [(NSText *)target selectedRange].length > 0)
		hasSelection = YES;

	for (NSMenuItem *item in [menu itemArray]) {
		if (item == closeTabMenuItem) {
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
			if (isDocWindow && [[windowController symbolController] symbolListIsOpen])
				[item setTitle:@"Hide Symbol List"];
			else
				[item setTitle:@"Show Symbol List"];
		}
	}

	[menu updateNormalModeMenuItemsWithSelection:hasSelection];
}

- (void)forceUpdateMenu:(NSMenu *)menu
{
	_trackingMainMenu = YES;

	[self menuNeedsUpdate:menu];

	for (NSMenuItem *item in [menu itemArray]) {
		NSMenu *submenu = [item submenu];
		if (submenu)
			[self forceUpdateMenu:submenu];
	}

	_trackingMainMenu = NO;
}

#pragma mark -
#pragma mark Input of scripted ex commands

- (BOOL)ex_cancel:(ViCommand *)command
{
	if (_busy)
		[NSApp stopModalWithCode:2];
	return YES;
}

- (BOOL)ex_execute:(ViCommand *)command
{
	_exString = [[[_fieldEditor textStorage] string] copy];
	if (_busy)
		[NSApp stopModalWithCode:0];
	_busy = NO;
	return YES;
}

- (NSString *)getExStringForCommand:(ViCommand *)command prefix:(NSString *)prefix
{
	ViMacro *macro = command.macro;

	if (_busy) {
		INFO(@"%s", "can't handle nested ex commands!");
		return nil;
	}

	_busy = YES;
	_exString = nil;

	if (macro) {
		NSInteger keyCode;
		if (_fieldEditor == nil) {
			_fieldEditorStorage = [[ViTextStorage alloc] init];
			_fieldEditor = [[ViTextView makeFieldEditorWithTextStorage:_fieldEditorStorage] retain];
		}
		[_fieldEditor setInsertMode:nil];
		[_fieldEditor setCaret:0];
		[_fieldEditor setString:prefix ?: @""];
		[_fieldEditor setDelegate:self];
		while (_busy && (keyCode = [macro pop]) != -1)
			[_fieldEditor.keyManager handleKey:keyCode];
	}

	if (_busy) {
		_busy = NO;
		return nil;
	}

	return [_exString autorelease];
}

- (NSString *)getExStringForCommand:(ViCommand *)command
{
	return [self getExStringForCommand:command prefix:nil];
}

@end

