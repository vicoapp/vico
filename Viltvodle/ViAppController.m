#import "ViAppController.h"
#import "ViThemeStore.h"
#import "ViLanguageStore.h"
#import "ViDocument.h"
#import "ViDocumentView.h"
#import "ViDocumentController.h"
#import "ViPreferencesController.h"
#import "TMFileURLProtocol.h"
#import "TxmtURLProtocol.h"
#import "Nu/Nu.h"
#import "JSON.h"
#import "ViError.h"

#include <sys/time.h>

@implementation ViAppController

@synthesize lastSearchPattern;
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
		sharedBuffers = [[NSMutableDictionary alloc] init];

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
	if (supportDirectory == nil)
		supportDirectory = [@"~/Library/Application Support/Viltvodle" stringByExpandingTildeInPath];
	return supportDirectory;
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
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
	    [NSArray arrayWithObject:[NSDictionary dictionaryWithObject:@"textmate" forKey:@"username"]], @"bundleRepositoryUsers",
	    [NSNumber numberWithBool:YES], @"explorecaseignore",
	    [NSNumber numberWithBool:NO], @"exploresortfolders",
	    nil]];

	/* Initialize languages and themes. */
	[ViLanguageStore defaultStore];
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
	                                             name:ViLanguageStoreBundleLoadedNotification
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
	[shellConn registerName:[NSString stringWithFormat:@"viltvodle.%u", (unsigned int)getuid()]];

	extern struct timeval launch_start;
	struct timeval launch_done, launch_diff;
	gettimeofday(&launch_done, NULL);
	timersub(&launch_done, &launch_start, &launch_diff);
	INFO(@"launched after %fs", launch_diff.tv_sec + (float)launch_diff.tv_usec / 1000000);

	NSString* consoleStartup = @"((NuConsoleWindowController alloc) init)"; 
	[[Nu parser] parseEval:consoleStartup]; 
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

- (NSMutableDictionary *)sharedBuffers
{
	return sharedBuffers;
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
#pragma mark Shell commands

/* Set some convenient global objects. */
- (void)exportGlobals:(id)parser
{
	ViWindowController *winCon = [ViWindowController currentWindowController];
	if (winCon) {
		[parser setValue:winCon.proxy forKey:@"window"];
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

- (id)evalExpression:(NSString *)expression error:(NSError **)outError
{
	id<NuParsing> parser = [Nu parser];

	[self exportGlobals:parser];

	id code = [parser parse:expression];
	if (code == nil) {
		if (outError)
			*outError = [ViError errorWithFormat:@"parse failed"];
		return nil;
	}
	id result = [parser eval:code];
	return result;
}

- (NSString *)eval:(NSString *)script
    withScriptPath:(NSString *)path
additionalBindings:(NSDictionary *)bindings
       errorString:(NSString **)errorString
       backChannel:(NSString *)channelName
{
	id<NuParsing> parser = [Nu parser];
	[self exportGlobals:parser];

	if (channelName) {
		NSDistantObject *backChannel = [NSConnection rootProxyForConnectionWithRegisteredName:channelName host:nil];
		[parser setValue:backChannel forKey:@"shellCommand"];
	}

	for (NSString *key in [bindings allKeys])
		if ([key isKindOfClass:[NSString class]])
			[parser setValue:[bindings objectForKey:key] forKey:key];

	DEBUG(@"evaluating script: {{{ %@ }}}", script);
	DEBUG(@"additional bindings: %@", bindings);

        [Nu loadNuFile:@"nu"            fromBundleWithIdentifier:@"nu.programming.framework" withContext:[parser context]];
        [Nu loadNuFile:@"bridgesupport" fromBundleWithIdentifier:@"nu.programming.framework" withContext:[parser context]];
        [Nu loadNuFile:@"cocoa"         fromBundleWithIdentifier:@"nu.programming.framework" withContext:[parser context]];
        [Nu loadNuFile:@"nibtools"      fromBundleWithIdentifier:@"nu.programming.framework" withContext:[parser context]];
        [Nu loadNuFile:@"viltvodle"     fromBundleWithIdentifier:@"se.bzero.Viltvodle" withContext:[parser context]];

	id code = [parser parse:script];
	if (code == nil) {
		if (errorString)
			*errorString = @"parse failed";
		return nil;
	}
	id result = nil;
	@try {
		result = [parser eval:code];
	}
	@catch (NSException *exception) {
		DEBUG(@"got exception %@", [exception name]);
		if (errorString)
			*errorString = [exception reason];
		return nil;
	}
	return [result JSONRepresentation];
}

- (NSError *)openURL:(NSString *)pathOrURL
{
	ViDocument *doc = [[ViDocumentController sharedDocumentController] openDocument:pathOrURL
									     andDisplay:YES
									 allowDirectory:YES];
	if (doc)
		[NSApp activateIgnoringOtherApps:YES];

	return nil;
}

@end

