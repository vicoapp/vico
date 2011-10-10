#import "NSString-scopeSelector.h"
#import "ViBundle.h"
#import "ViBundleCommand.h"
#import "ViBundleSnippet.h"
#import "ViCommandMenuItemView.h"
#import "ViTextView.h"
#import "ViBundleStore.h"
#import "ViAppController.h"
#import "ViEventManager.h"
#import "ViFileExplorer.h"
#include "logging.h"

@implementation ViBundle

@synthesize languages = _languages;
@synthesize path = _path;
@synthesize items = _items;
@synthesize preferences = _preferences;

+ (NSColor *)hashRGBToColor:(NSString *)hashRGB
{
	int r, g, b, a;
	const char *s = [hashRGB UTF8String];
	if (s == NULL)
		return nil;
	int rc = sscanf(s, "#%02X%02X%02X%02X", &r, &g, &b, &a);
	if (rc != 3 && rc != 4)
		return nil;
	if (rc == 3)
		a = 255;

	return [NSColor colorWithCalibratedRed:(float)r/255.0
					 green:(float)g/255.0
					  blue:(float)b/255.0
					 alpha:(float)a/255.0];
}

+ (void)normalizeSettings:(NSDictionary *)settings
	   intoDictionary:(NSMutableDictionary *)normalizedPreference
	       withParser:(NuParser *)aParser
{
	if (normalizedPreference == nil) {
		INFO(@"%s", "missing normalized preference dictionary");
		return;
	}

	NSColor *color;
	NSString *value;

	/*
	 * Convert RGB color strings to actual color objects, with keys directly appropriate for NSAttributedStrings.
	 */
	if ((value = [settings objectForKey:@"foreground"]) != nil) {
		if ((color = [self hashRGBToColor:value]) != nil)
			[normalizedPreference setObject:color
						 forKey:NSForegroundColorAttributeName];
	}

	if ((value = [settings objectForKey:@"background"]) != nil) {
		if ((color = [self hashRGBToColor:value]) != nil)
			[normalizedPreference setObject:color
						 forKey:NSBackgroundColorAttributeName];
	}

	NSUInteger underlineStyle = NSUnderlineStyleNone;

	if ((value = [settings objectForKey:@"fontStyle"]) != nil) {
		if ([value rangeOfString:@"underline"].location != NSNotFound)
			underlineStyle = NSUnderlineStyleSingle;
		if ([value rangeOfString:@"italic"].location != NSNotFound)
			[normalizedPreference setObject:[NSNumber numberWithFloat:0.3]
						 forKey:NSObliquenessAttributeName];
		if ([value rangeOfString:@"bold"].location != NSNotFound)
			[normalizedPreference setObject:[NSNumber numberWithFloat:-3.0]
						 forKey:NSStrokeWidthAttributeName];
	}

	if ([settings objectForKey:@"underline"] != nil)
		underlineStyle = NSUnderlineStyleSingle;

	if ([settings objectForKey:@"italic"] != nil)
		[normalizedPreference setObject:[NSNumber numberWithFloat:0.3]
					 forKey:NSObliquenessAttributeName];

	if ([settings objectForKey:@"bold"] != nil)
		[normalizedPreference setObject:[NSNumber numberWithFloat:-3.0]
					 forKey:NSStrokeWidthAttributeName];

	if ((value = [settings objectForKey:@"underlineColor"]) != nil)
		if ((color = [self hashRGBToColor:value]) != nil)
			[normalizedPreference setObject:color
						 forKey:NSUnderlineColorAttributeName];

	if ((value = [settings objectForKey:@"underlineStyle"]) != nil) {
		if ([value rangeOfString:@"single"].location != NSNotFound)
			underlineStyle = NSUnderlineStyleSingle;
		else if ([value rangeOfString:@"double"].location != NSNotFound)
			underlineStyle = NSUnderlineStyleDouble;
		else if ([value rangeOfString:@"thick"].location != NSNotFound)
			underlineStyle = NSUnderlineStyleThick;
	}

	if (underlineStyle != NSUnderlineStyleNone)
		[normalizedPreference setObject:[NSNumber numberWithUnsignedInteger:underlineStyle]
					 forKey:NSUnderlineStyleAttributeName];

	NSShadow *shadow = nil;

	if ((value = [settings objectForKey:@"shadowColor"]) != nil) {
		if ((color = [self hashRGBToColor:value]) != nil) {
			if (shadow == nil)
				shadow = [[NSShadow alloc] init];
			[shadow setShadowColor:color];
		}
	}

	if ((value = [settings objectForKey:@"shadowBlurRadius"]) != nil && [value respondsToSelector:@selector(floatValue)]) {
		CGFloat radius = [value floatValue];
		if (radius >= 0) {
			if (shadow == nil)
				shadow = [[NSShadow alloc] init];
			[shadow setShadowBlurRadius:radius];
		}
	}

	if ((value = [settings objectForKey:@"shadowVerticalOffset"]) != nil && [value respondsToSelector:@selector(floatValue)]) {
		if (shadow == nil)
			shadow = [[NSShadow alloc] init];
		NSSize offset = [shadow shadowOffset];
		offset.height = [value floatValue];
		[shadow setShadowOffset:offset];
	}

	if ((value = [settings objectForKey:@"shadowHorizontalOffset"]) != nil && [value respondsToSelector:@selector(floatValue)]) {
		if (shadow == nil)
			shadow = [[NSShadow alloc] init];
		NSSize offset = [shadow shadowOffset];
		offset.width = [value floatValue];
		[shadow setShadowOffset:offset];
	}

	if (shadow) {
		[normalizedPreference setObject:shadow
					 forKey:NSShadowAttributeName];
		[shadow release];
	}

	if ((value = [settings objectForKey:@"indentExpression"]) != nil) {
		@try {
			NuCell *cell = [aParser parse:value];
			if (cell == nil)
				INFO(@"Failed to parse indent expression: %@", value);
			else {
				NuBlock *code = [[NuBlock alloc] initWithParameters:[NuCell cellWithCar:nil cdr:nil]
									       body:cell
									    context:[aParser context]];
				DEBUG(@"got code %@ (a %@)", code, NSStringFromClass([code class]));
				[normalizedPreference setObject:code
							 forKey:@"indentExpressionBlock"];
				[code release];
			}
		}
		@catch (NSException *exception) {
			INFO(@"Failed to parse indent expression: %@: %@", [exception name], [exception reason]);
		}
	}
}

+ (void)normalizeSettings:(NSDictionary *)settings
	   intoDictionary:(NSMutableDictionary *)normalizedPreference;
{
	[self normalizeSettings:settings intoDictionary:normalizedPreference withParser:nil];
}

+ (void)normalizePreference:(NSDictionary *)preference
             intoDictionary:(NSMutableDictionary *)normalizedPreference
                 withParser:(NuParser *)aParser
{
	NSDictionary *settings = [preference objectForKey:@"settings"];
	if (![settings isKindOfClass:[NSDictionary class]]) {
		INFO(@"missing settings dictionary in preference: %@", preference);
		return;
	}

	[self normalizeSettings:settings intoDictionary:normalizedPreference withParser:aParser];
}

+ (void)normalizePreference:(NSDictionary *)preference
             intoDictionary:(NSMutableDictionary *)normalizedPreference
{
        [self normalizePreference:preference intoDictionary:normalizedPreference withParser:nil];
}

+ (void)setupEnvironment:(NSMutableDictionary *)env
             forTextView:(ViTextView *)textView
	      inputRange:(NSRange)inputRange
		  window:(NSWindow *)window
		  bundle:(ViBundle *)bundle
{
	[env setObject:NSHomeDirectory() forKey:@"HOME"];

	/* OS variables. */
	[env addEntriesFromDictionary:[[NSProcessInfo processInfo] environment]];

	/* Application-level variables.
	 */
	NSString *appPath = [[NSBundle mainBundle] bundlePath];
	[env setObject:appPath forKey:@"TM_APP_PATH"];
	NSString *supportPath = [appPath stringByAppendingPathComponent:@"Contents/Resources/Support"];
	[env setObject:supportPath forKey:@"TM_SUPPORT_PATH"];
	[env setObject:[NSString stringWithFormat:@"%lu", (unsigned long)getpid()] forKey:@"TM_PID"];
	[env setObject:[supportPath stringByAppendingPathComponent:@"lib/bash_init.sh"] forKey:@"BASH_ENV"];
	[env setObject:NSFullUserName() forKey:@"TM_FULLNAME"];

	// TextMate 2 moves the CommitWindow app into an SCM bundle and makes git, hg and other bundles require it.
	// The SCM bundle then export the TM_SCM_COMMIT_WINDOW variable for other bundles to use.
	[env setObject:[supportPath stringByAppendingPathComponent:@"/bin/CommitWindow.app/Contents/MacOS/CommitWindow"] forKey:@"TM_SCM_COMMIT_WINDOW"];

	/* Text-view related variables.
	 */
	if (textView) {
		ViTextStorage *ts = [textView textStorage];

		NSString *line = [ts lineAtLocation:[textView caret]];
		if (line)
			[env setObject:line forKey:@"TM_CURRENT_LINE"];

		NSString *word = [ts wordAtLocation:[textView caret] range:nil acceptAfter:YES];
		if (word)
			[env setObject:word forKey:@"TM_CURRENT_WORD"];

		[env setObject:[NSString stringWithFormat:@"%li", [ts columnOffsetAtLocation:[textView caret]]] forKey:@"TM_LINE_INDEX"];
		[env setObject:[NSString stringWithFormat:@"%li", [textView currentLine]] forKey:@"TM_LINE_NUMBER"];

		NSURL *url = [textView.document fileURL];
		if (url) {
			if ([url isFileURL]) {
				[env setObject:[[url path] stringByDeletingLastPathComponent] forKey:@"TM_DIRECTORY"];
				[env setObject:[url path] forKey:@"TM_FILEPATH"];
			}
			[env setObject:[[url path] lastPathComponent] forKey:@"TM_FILENAME"];
			[env setObject:[url absoluteString] forKey:@"TM_FILEURL"];
		}

		NSString *scope = [[[textView.document scopeAtLocation:[textView caret]] scopes] componentsJoinedByString:@" "];
		if (scope)
			[env setObject:scope forKey:@"TM_SCOPE"];

		if (inputRange.location != NSNotFound) {
			[env setObject:[NSString stringWithFormat:@"%li", [ts columnAtLocation:inputRange.location]] forKey:@"TM_INPUT_START_COLUMN"];
			[env setObject:[NSString stringWithFormat:@"%li", [ts columnAtLocation:NSMaxRange(inputRange)]] forKey:@"TM_INPUT_END_COLUMN"];

			[env setObject:[NSString stringWithFormat:@"%li", [ts columnOffsetAtLocation:inputRange.location]] forKey:@"TM_INPUT_START_LINE_INDEX"];
			[env setObject:[NSString stringWithFormat:@"%li", [ts columnOffsetAtLocation:NSMaxRange(inputRange)]] forKey:@"TM_INPUT_END_LINE_INDEX"];

			[env setObject:[NSString stringWithFormat:@"%li", [ts lineNumberAtLocation:inputRange.location]] forKey:@"TM_INPUT_START_LINE"];
			[env setObject:[NSString stringWithFormat:@"%li", [ts lineNumberAtLocation:NSMaxRange(inputRange)]] forKey:@"TM_INPUT_END_LINE"];
		}

		NSRange selectedRange = [textView selectedRange];
		if (selectedRange.length > 0)
			[env setObject:[[ts string] substringWithRange:selectedRange] forKey:@"TM_SELECTED_TEXT"];
	}

	/* File-related variables.
	 */
	ViFileExplorer *explorer = nil;
	ViWindowController *windowController = [window windowController];
	if ([windowController respondsToSelector:@selector(explorer)])
		explorer = windowController.explorer;
	if (explorer && explorer.rootURL) {
		NSURL *url = explorer.rootURL;
		NSSet *selectedURLs = [explorer clickedURLs];

		[env setObject:[url absoluteString] forKey:@"TM_PROJECT_URL"];
		if ([url isFileURL])
			[env setObject:[url path] forKey:@"TM_PROJECT_DIRECTORY"];

		NSMutableString *urls = [NSMutableString string];
		for (url in selectedURLs) {
			[urls appendFormat:[NSString stringWithFormat:@"'%@' ",
			    [[url absoluteString] stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"]]];
		}
		[env setObject:[urls stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] forKey:@"TM_SELECTED_URLS"];

		url = [selectedURLs anyObject];
		if (url)
			[env setObject:[url absoluteString] forKey:@"TM_SELECTED_URL"];

		if ([url isFileURL]) {
			NSMutableString *paths = [NSMutableString string];
			for (url in selectedURLs) {
				[paths appendFormat:[NSString stringWithFormat:@"'%@' ",
				    [[url path] stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"]]];
			}
			[env setObject:[paths stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] forKey:@"TM_SELECTED_FILES"];

			url = [selectedURLs anyObject];
			if (url)
				[env setObject:[url path] forKey:@"TM_SELECTED_FILE"];
		}
	}

	/* Bundle-specific variables.
	*/
	NSString *bundleSupportPath = nil;
	if (bundle) {
		[env setObject:[bundle path] forKey:@"TM_BUNDLE_PATH"];
		bundleSupportPath = [bundle supportPath];
		[env setObject:bundleSupportPath forKey:@"TM_BUNDLE_SUPPORT"];
	}

	/* User-defaults variables.
	 */
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	if ([defs integerForKey:@"expandtab"] == NSOnState)
		[env setObject:@"YES" forKey:@"TM_SOFT_TABS" ];
	else
		[env setObject:@"NO" forKey:@"TM_SOFT_TABS" ];
	[env setObject:[defs stringForKey:@"shiftwidth"] forKey:@"TM_TAB_SIZE"];

	/* Some bundles check for dialog2 support by matching the DIALOG
	 * environment variable with /2$/. This uses the new(er) infrastructure
	 * with ui.rb, which we have better support for (although limited).
	 */
	[env setObject:@"/nope/vico_doesnt_support_dialog2" forKey:@"DIALOG"];

	/*
	 * Global (static) environment variables.
	 */
	[env addEntriesFromDictionary:[defs dictionaryForKey:@"environment"]];

	/*
	 * shellVariables from bundle preferences
	 */
	NSDictionary *shellVariables = [[ViBundleStore defaultStore] shellVariablesForScope:[textView.document scopeAtLocation:[textView caret]]];
	if (shellVariables)
		[env addEntriesFromDictionary:shellVariables];

	/* Augment PATH variable.
	 */
	NSString *path = [env objectForKey:@"PATH"];
	if (path == nil)
		path = [NSString stringWithCString:getenv("PATH") encoding:NSUTF8StringEncoding];
	if (path == nil)
		path = [NSString stringWithCString:getenv("PATH") encoding:NSISOLatin1StringEncoding];
	if (path == nil)
		path = @"/sbin:/usr/sbin:/bin:/usr/bin:/usr/X11R6/bin:/usr/local/sbin:/usr/local/bin";
	[env setObject:[NSString stringWithFormat:@"%@:%@%s%@",
		path,
		[supportPath stringByAppendingPathComponent:@"bin"],
		bundleSupportPath ? ":" : "",
		bundleSupportPath ? [bundleSupportPath stringByAppendingPathComponent:@"bin"] : @""]
	    forKey:@"PATH"];
}

+ (void)setupEnvironment:(NSMutableDictionary *)env
             forTextView:(ViTextView *)textView
		  window:(NSWindow *)aWindow
		  bundle:(ViBundle *)bundle
{
	return [ViBundle setupEnvironment:env
			      forTextView:textView
			       inputRange:NSMakeRange(NSNotFound, 0)
				   window:aWindow
				   bundle:bundle];
}

+ (NSDictionary *)environment
{
	NSMutableDictionary *env = [NSMutableDictionary dictionary];
	[ViBundle setupEnvironment:env forTextView:nil window:nil bundle:nil];
	return env;
}

- (ViBundle *)initWithDirectory:(NSString *)bundleDirectory
{
	self = [super init];
	if (self) {
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *plistPath = [bundleDirectory stringByAppendingPathComponent:@"info.plist"];
		if (![fm fileExistsAtPath:plistPath]) {
			[self release];
			return nil;
		}

		_info = [[NSDictionary alloc] initWithContentsOfFile:plistPath];
		if (_info == nil || ![_info isKindOfClass:[NSDictionary class]]) {
			INFO(@"malformed info.plist in bundle %@", bundleDirectory);
			[self release];
			return nil;
		}
		if ([_info objectForKey:@"isDelta"]) {
			INFO(@"delta bundles not implemented, at %@", bundleDirectory);
			[self release];
			return nil;
		}
		if ([_info objectForKey:@"uuid"] == nil) {
			INFO(@"missing uuid in info.plist in bundle %@", bundleDirectory);
			[self release];
			return nil;
		}

		_languages = [[NSMutableArray alloc] init];
		_preferences = [[NSMutableArray alloc] init];
		_cachedPreferences = [[NSMutableDictionary alloc] init];
		_uuids = [[NSMutableDictionary alloc] init];
		_items = [[NSMutableArray alloc] init];
		_path = [bundleDirectory copy];
		_parser = [[NuParser alloc] init];

		NSString *dir = [_path stringByAppendingPathComponent:@"Syntaxes"];
		NSString *file;
		for (file in [fm contentsOfDirectoryAtPath:dir error:NULL]) {
			if ([file hasSuffix:@".tmLanguage"] || [file hasSuffix:@".plist"]) {
				ViLanguage *language = [[ViLanguage alloc] initWithPath:[dir stringByAppendingPathComponent:file]
									      forBundle:self];
				if (language) {
					[_languages addObject:language];
					[language release];
				}
			}
		}

		dir = [_path stringByAppendingPathComponent:@"Preferences"];
		for (file in [fm contentsOfDirectoryAtPath:dir error:NULL])
			if ([file hasSuffix:@".plist"] || [file hasSuffix:@".tmPreferences"]) {
				NSString *f = [dir stringByAppendingPathComponent:file];
				NSDictionary *plist = [NSMutableDictionary dictionaryWithContentsOfFile:f];
				if (![plist isKindOfClass:[NSDictionary class]]) {
					INFO(@"%@: failed to load plist", f);
					continue;
				}

				[ViBundle normalizePreference:plist
					       intoDictionary:[plist objectForKey:@"settings"]
						   withParser:_parser];
				[_preferences addObject:plist];
			}

		dir = [_path stringByAppendingPathComponent:@"Snippets"];
		for (file in [fm contentsOfDirectoryAtPath:dir error:NULL])
			if ([file hasSuffix:@".tmSnippet"] || [file hasSuffix:@".plist"])  {
				NSString *f = [dir stringByAppendingPathComponent:file];
				NSDictionary *plist = [NSMutableDictionary dictionaryWithContentsOfFile:f];
				if (![plist isKindOfClass:[NSDictionary class]]) {
					INFO(@"%@: failed to load plist", f);
					continue;
				}
				ViBundleSnippet *snippet = [(ViBundleSnippet *)[ViBundleSnippet alloc] initFromDictionary:plist
														 inBundle:self];
				if (snippet) {
					[_items addObject:snippet];
					[_uuids setObject:snippet forKey:snippet.uuid];
					[snippet release];
				}
			}

		dir = [_path stringByAppendingPathComponent:@"Commands"];
		for (file in [fm contentsOfDirectoryAtPath:dir error:NULL])
			if ([file hasSuffix:@".tmCommand"] || [file hasSuffix:@".plist"]) {
				NSString *f = [dir stringByAppendingPathComponent:file];
				NSDictionary *plist = [NSMutableDictionary dictionaryWithContentsOfFile:f];
				if (![plist isKindOfClass:[NSDictionary class]]) {
					INFO(@"%@: failed to load plist", f);
					continue;
				}
				ViBundleCommand *command = [(ViBundleCommand *)[ViBundleCommand alloc] initFromDictionary:plist
														 inBundle:self];
				if (command) {
					[_items addObject:command];
					[_uuids setObject:command forKey:command.uuid];
					[command release];
				}
			}
	}
	return self;
}

- (BOOL)loadPluginCode
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *file = [_path stringByAppendingPathComponent:@"main.nu"];
	BOOL isDir = NO;
	if ([fm fileExistsAtPath:file isDirectory:&isDir] && !isDir) {
		NSString *script = [NSString stringWithContentsOfFile:file
							     encoding:NSUTF8StringEncoding
								error:nil];
		if (script) {
			INFO(@"loading plugin code for bundle %@", _path);
			NSDictionary *bindings = [NSDictionary dictionaryWithObjectsAndKeys:
				_path, @"bundlePath",
				nil];
			NSError *error = nil;
			[[NSApp delegate] eval:script
				    withParser:_parser
				      bindings:bindings
					 error:&error];
			if (error) {
				INFO(@"%@: %@", file, [error localizedDescription]);
				return NO;
			}
		}
	}

	return YES;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	[_path release];
	[_info release];
	[_languages release];
	[_preferences release];
	[_items release];
	[_cachedPreferences release];
	[_uuids release];
	[_parser release];
	[super dealloc];
}

- (NSString *)supportPath
{
	return [_path stringByAppendingPathComponent:@"Support"];
}

- (NSString *)name
{
	return [_info objectForKey:@"name"];
}

- (NSString *)uuid
{
	return [_info objectForKey:@"uuid"];
}

- (NSDictionary *)preferenceItems:(NSArray *)prefsNames
{
	NSMutableDictionary *prefsForScope = [NSMutableDictionary dictionary];

	for (NSDictionary *prefs in _preferences) {
		NSDictionary *settings = [prefs objectForKey:@"settings"];

		NSMutableDictionary *prefsValues = nil;
		for (NSString *prefsName in prefsNames) {
			id prefsValue = [settings objectForKey:prefsName];
			if (prefsValue) {
				if (prefsValues == nil)
					prefsValues = [NSMutableDictionary dictionary];
				[prefsValues setObject:prefsValue forKey:prefsName];
			}
		}

		if (prefsValues) {
			NSString *scope = [prefs objectForKey:@"scope"];
			NSMutableDictionary *oldPrefsValues = [prefsForScope objectForKey:scope];
			if (oldPrefsValues)
				[oldPrefsValues addEntriesFromDictionary:prefsValues];
			else
				[prefsForScope setObject:prefsValues forKey:scope];
		}
	}

	return prefsForScope;
}

- (NSDictionary *)preferenceItem:(NSString *)prefsName
{
	NSMutableDictionary *prefsForScope = [NSMutableDictionary dictionary];

	for (NSDictionary *prefs in _preferences) {
		NSDictionary *settings = [prefs objectForKey:@"settings"];
		id prefsValue = [settings objectForKey:prefsName];
		if (prefsValue) {
			NSString *scope = [prefs objectForKey:@"scope"];
			if (scope)
				[prefsForScope setObject:prefsValue forKey:scope];
		}
	}

	return prefsForScope;
}

- (NSMenu *)submenu:(id)menuLayout
           withName:(NSString *)name
         inMainMenu:(NSDictionary *)mainMenu
           forScope:(ViScope *)scope
       enabledItems:(NSUInteger *)enabledItemsPtr
       hasSelection:(BOOL)hasSelection
               font:(NSFont *)aFont
{
	int matches = 0;
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:name] autorelease];
	[menu setAutoenablesItems:NO];
	NSDictionary *submenus = nil;
	if ([mainMenu isKindOfClass:[NSDictionary class]])
		submenus = [mainMenu objectForKey:@"submenus"];

	NSArray *menuItems = nil;
	if ([menuLayout isKindOfClass:[NSDictionary class]]) {
		menuItems = [menuLayout objectForKey:@"items"];
		if (![menuItems isKindOfClass:[NSArray class]])
			return nil;
	} else if ([menuLayout isKindOfClass:[NSArray class]])
		menuItems = menuLayout;
	else
		return nil;

	for (NSString *uuid in menuItems) {
		id op;
		NSMenuItem *item;

		if ([uuid isEqualToString:@"------------------------------------"]) {
			item = [NSMenuItem separatorItem];
			[menu addItem:item];
		} else if ((op = [_uuids objectForKey:uuid]) != nil) {
			SEL selector = NULL;
			if ([op isKindOfClass:[ViBundleItem class]]) {
				NSString *scopeSelector = [op scopeSelector];
				if (scopeSelector == nil || [scopeSelector match:scope] > 0) {
					matches++;
					selector = @selector(performBundleItem:);
				}
				/* otherwise selector is NULL => disabled menu item */

				/* Replace "Thing / Selection" depending on hasSelection.
				 */
				NSMutableString *title = [[[op name] mutableCopy] autorelease];
				NSRange r = [title rangeOfString:@" / Selection"];
				if (r.location != NSNotFound) {
					if (hasSelection) {
						NSCharacterSet *set = [NSCharacterSet letterCharacterSet];
						NSInteger l;
						for (l = r.location; l > 0; l--)
							if (![set characterIsMember:[title characterAtIndex:l - 1]])
								break;
						NSRange altr = NSMakeRange(l, r.location - l + 3);
						if (altr.length > 3)
							[title deleteCharactersInRange:altr];
					} else
						[title deleteCharactersInRange:r];
				}

				item = [menu addItemWithTitle:title
						       action:selector
						keyEquivalent:[op keyEquivalent]];
				[item setKeyEquivalentModifierMask:[op modifierMask]];
				[item setRepresentedObject:op];
				[item setEnabled:(selector != NULL)];

				NSString *tabTrigger = [op tabTrigger];
				if ([tabTrigger length] > 0) {
					/* Set a special view for drawing the tab trigger. */
					ViCommandMenuItemView *view;
					view = [[[ViCommandMenuItemView alloc] initWithTitle:[op name]
										  tabTrigger:tabTrigger
											font:aFont] autorelease];
					[item setView:view];
				}
			} else
				INFO(@"unhandled bundle item %@", op);
		} else {
			NSDictionary *submenuLayout = [submenus objectForKey:uuid];
			if ([submenuLayout isKindOfClass:[NSDictionary class]]) {
				NSUInteger submatches = 0;
				NSMenu *submenu = [self submenu:submenuLayout
				                       withName:[submenuLayout objectForKey:@"name"]
				                     inMainMenu:mainMenu
				                       forScope:scope
				                   enabledItems:&submatches
				                   hasSelection:hasSelection
							   font:aFont];
				if (submenu) {
					matches += submatches;
					item = [menu addItemWithTitle:[submenuLayout objectForKey:@"name"]
					                       action:NULL
					                keyEquivalent:@""];
					[item setSubmenu:submenu];
					if (submatches == 0)
						[item setEnabled:NO];
				}
			} else
				DEBUG(@"missing menu item %@ in bundle %@", uuid, [self name]);
		}

	}

	if (enabledItemsPtr)
		*enabledItemsPtr = matches;

	return menu;
}

- (NSMenu *)menuForScope:(ViScope *)scope
            hasSelection:(BOOL)hasSelection
                    font:(NSFont *)aFont
{
	NSDictionary *mainMenu = [_info objectForKey:@"mainMenu"];
	if (mainMenu == nil) {
		/* Fall back to simple list of bundle items. */
		mainMenu = [_info objectForKey:@"ordering"];
		if (![mainMenu isKindOfClass:[NSArray class]])
			return nil;
	} else if (![mainMenu isKindOfClass:[NSDictionary class]])
		return nil;

	NSUInteger matches = 0;
	NSMenu *menu = [self submenu:mainMenu
	                    withName:[self name]
	                  inMainMenu:mainMenu
	                    forScope:scope
	                enabledItems:&matches
	                hasSelection:hasSelection
				font:aFont];

	return matches == 0 ? nil : menu;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViBundle %p: %@ (%@)>", self, [self name], [self uuid]];
}

@end

