#import "ViAppController.h"
#import "ViThemeStore.h"
#import "ViBundleStore.h"
#import "ViDocument.h"
#import "ViDocumentView.h"
#import "ViDocumentController.h"
#import "ViPreferencesController.h"
#import "TMFileURLProtocol.h"
#import "TxmtURLProtocol.h"
#import "JSON.h"
#import "ViError.h"
#import "ViCommandMenuItemView.h"
#import "ViTextView.h"

#include <sys/time.h>

@implementation ViAppController

@synthesize encodingMenu;

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
	[NSApp activateIgnoringOtherApps:YES];

	[[NSFileManager defaultManager] createDirectoryAtPath:[ViAppController supportDirectory]
				  withIntermediateDirectories:YES
						   attributes:nil
							error:nil];

	NSUserDefaults *userDefs = [NSUserDefaults standardUserDefaults];

	/* initialize default defaults */
	[userDefs registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
	    [NSNumber numberWithInt:8], @"shiftwidth",
	    [NSNumber numberWithInt:8], @"tabstop",
	    [NSNumber numberWithBool:YES], @"autoindent",
	    [NSNumber numberWithBool:YES], @"smartindent",
	    [NSNumber numberWithBool:YES], @"smartpair",
	    [NSNumber numberWithBool:YES], @"ignorecase",
	    [NSNumber numberWithBool:YES], @"smartcase",
	    [NSNumber numberWithBool:YES], @"expandtabs",
	    [NSNumber numberWithBool:YES], @"number",
	    [NSNumber numberWithBool:YES], @"autocollapse",
	    [NSNumber numberWithBool:NO], @"hidetab",
	    [NSNumber numberWithBool:YES], @"searchincr",
	    [NSNumber numberWithBool:NO], @"showguide",
	    [NSNumber numberWithBool:YES], @"wrap",
	    [NSNumber numberWithBool:YES], @"antialias",
	    [NSNumber numberWithInt:80], @"guidecolumn",
	    [NSNumber numberWithFloat:11.0], @"fontsize",
	    @"vim", @"undostyle",
	    @"Menlo Regular", @"fontname",
	    @"Sunset", @"theme",
	    @"(CVS|_darcs|.svn|.git|~$|\\.bak$|\\.o$)", @"skipPattern",
	    [NSArray arrayWithObjects:
		[NSDictionary dictionaryWithObject:@"vicoapp" forKey:@"username"],
		[NSDictionary dictionaryWithObject:@"textmate" forKey:@"username"],
		[NSDictionary dictionaryWithObject:@"jsallis" forKey:@"username"],
		[NSDictionary dictionaryWithObject:@"kswedberg" forKey:@"username"],
		nil], @"bundleRepositoryUsers",
	    [NSNumber numberWithBool:YES], @"explorecaseignore",
	    [NSNumber numberWithBool:NO], @"exploresortfolders",
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

	NSSortDescriptor *sdesc = [[NSSortDescriptor alloc] initWithKey:@"title"
	                                                      ascending:YES];
	[array sortUsingDescriptors:[NSArray arrayWithObject:sdesc]];
	for (item in array)
		[encodingMenu addItem:item];

	[TMFileURLProtocol registerProtocol];
	[TxmtURLProtocol registerProtocol];

	//shellConn = [NSConnection serviceConnectionWithName:@"chunky bacon" rootObject:self];
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

	NSString *consoleStartup = @"((NuConsoleWindowController alloc) init)"; 
	[self eval:consoleStartup error:nil]; 

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
- (void)exportGlobals:(id)parser
{
	ViWindowController *winCon = [ViWindowController currentWindowController];
	if (winCon) {
		[parser setValue:winCon.proxy forKey:@"window"];
		[parser setValue:winCon.explorer forKey:@"explorer"];
		id<ViViewController> view = [winCon currentView];
		if (view) {
			[parser setValue:view forKey:@"view"];
			if ([view isKindOfClass:[ViDocumentView class]]) {
				ViTextView *textView = [(ViDocumentView *)view textView];
				[parser setValue:textView.proxy forKey:@"text"];
			}
		}
		ViDocument *doc = [winCon currentDocument];
		if (doc)
			[parser setValue:doc.proxy forKey:@"document"];
	}
}

- (void)loadStandardModules:(id<NuParsing>)parser
{
	NSMutableDictionary *context = [(NuParser *)parser context];
	[Nu loadNuFile:@"nu"            fromBundleWithIdentifier:@"nu.programming.framework" withContext:context];
	[Nu loadNuFile:@"bridgesupport" fromBundleWithIdentifier:@"nu.programming.framework" withContext:context];
	[Nu loadNuFile:@"cocoa"         fromBundleWithIdentifier:@"nu.programming.framework" withContext:context];
	[Nu loadNuFile:@"nibtools"      fromBundleWithIdentifier:@"nu.programming.framework" withContext:context];
	// [Nu loadNuFile:@"cblocks"       fromBundleWithIdentifier:@"nu.programming.framework" withContext:context];
	[Nu loadNuFile:@"vico"          fromBundleWithIdentifier:@"se.bzero.Vico" withContext:context];
}

- (id)eval:(NSString *)script
withParser:(id<NuParsing>)parser
     error:(NSError **)outError
{
	[self exportGlobals:parser];

	DEBUG(@"evaluating script: {{{ %@ }}}", script);

	id code = [parser parse:script];
	if (code == nil) {
		if (outError)
			*outError = [ViError errorWithFormat:@"parse failed"];
		return nil;
	}
	id result = nil;
	@try {
		result = [parser eval:code];
	}
	@catch (NSException *exception) {
		if (outError)
			*outError = [ViError errorWithFormat:@"Got exception %@:\n%@", [exception name], [exception reason]];
		return nil;
	}

	return result;
}

- (id)eval:(NSString *)script
     error:(NSError **)outError
{
	return [self eval:script withParser:[Nu parser] error:outError];
}

#pragma mark -
#pragma mark Shell commands

- (NSString *)eval:(NSString *)script
additionalBindings:(NSDictionary *)bindings
       errorString:(NSString **)errorString
       backChannel:(NSString *)channelName
{
	id<NuParsing> parser = [Nu parser];

	if (channelName) {
		NSDistantObject *backChannel = [NSConnection rootProxyForConnectionWithRegisteredName:channelName host:nil];
		[parser setValue:backChannel forKey:@"shellCommand"];
	}

	DEBUG(@"additional bindings: %@", bindings);
	for (NSString *key in [bindings allKeys])
		if ([key isKindOfClass:[NSString class]])
			[parser setValue:[bindings objectForKey:key] forKey:key];

	NSError *error = nil;
	id result = [self eval:script withParser:parser error:&error];
	if (error && errorString)
		*errorString = [error localizedDescription];

	if ([result isKindOfClass:[NSNull class]])
		return nil;
	return [result JSONRepresentation];
}

- (NSError *)openURL:(NSString *)pathOrURL
{
	ViDocumentController *docCon = [ViDocumentController sharedDocumentController];
	ViDocument *doc = [docCon openDocument:pathOrURL
				    andDisplay:YES
				allowDirectory:YES];
	if (doc)
		[NSApp activateIgnoringOtherApps:YES];

	return nil;
}

#pragma mark -

- (void)menuNeedsUpdate:(NSMenu *)menu
{
	ViRegexp *rx = [[ViRegexp alloc] initWithString:@" +\\((.*?)\\)( *\\((.*?)\\))?$"];

	for (NSMenuItem *item in [menu itemArray]) {
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

				BOOL hasSelection = NO;
				NSWindow *window = [[NSApplication sharedApplication] mainWindow];
				NSResponder *target = [window firstResponder];
				if ([target respondsToSelector:@selector(selectedRange)]) {
					if ([(NSText *)target selectedRange].length > 0)
						hasSelection = YES;
				}

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
				} else if ([item isEnabled]) {
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
				[item setTitle:newTitle];
			}

			[item setTag:4001];	/* mark as already updated */
		}
	}
}

@end

