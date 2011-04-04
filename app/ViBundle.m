#import "NSString-scopeSelector.h"
#import "ViBundle.h"
#import "ViBundleCommand.h"
#import "ViBundleSnippet.h"
#import "ViCommandMenuItemView.h"
#import "ViTextView.h"
#import "ViLanguageStore.h"
#import "logging.h"

@implementation ViBundle

@synthesize languages;
@synthesize path;
@synthesize items;

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

+ (void)normalizePreference:(NSDictionary *)preference
             intoDictionary:(NSMutableDictionary *)normalizedPreference
{
	NSDictionary *settings = [preference objectForKey:@"settings"];
	if (settings == nil) {
		INFO(@"missing settings dictionary in preference: %@", preference);
		return;
	}

	if (normalizedPreference == nil) {
		INFO(@"missing normalized preference dictionary in preference: %@", preference);
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

	if ((value = [settings objectForKey:@"fontStyle"]) != nil) {
		if ([value rangeOfString:@"underline"].location != NSNotFound)
			[normalizedPreference setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle]
						 forKey:NSUnderlineStyleAttributeName];
		if ([value rangeOfString:@"italic"].location != NSNotFound)
			[normalizedPreference setObject:[NSNumber numberWithFloat:0.3]
						 forKey:NSObliquenessAttributeName];
		if ([value rangeOfString:@"bold"].location != NSNotFound)
			[normalizedPreference setObject:[NSNumber numberWithFloat:-3.0]
						 forKey:NSStrokeWidthAttributeName];
	}

	if ([settings objectForKey:@"underline"] != nil)
		[normalizedPreference setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle]
					 forKey:NSUnderlineStyleAttributeName];

	if ([settings objectForKey:@"italic"] != nil)
		[normalizedPreference setObject:[NSNumber numberWithFloat:0.3]
					 forKey:NSObliquenessAttributeName];

	if ([settings objectForKey:@"bold"] != nil)
		[normalizedPreference setObject:[NSNumber numberWithFloat:-3.0]
					 forKey:NSStrokeWidthAttributeName];
}

+ (void)setupEnvironment:(NSMutableDictionary *)env
             forTextView:(ViTextView *)textView
{
	ViTextStorage *ts = [textView textStorage];

	NSString *appPath = [[NSBundle mainBundle] bundlePath];
	[env setObject:appPath forKey:@"TM_APP_PATH"];

	[env setObject:[NSString stringWithFormat:@"%lu", (unsigned long)getpid()] forKey:@"TM_PID"];

	NSString *supportPath = [appPath stringByAppendingPathComponent:@"Contents/Resources/Support"];
	[env setObject:supportPath forKey:@"TM_SUPPORT_PATH"];

	[env setObject:[supportPath stringByAppendingPathComponent:@"lib/bash_init.sh"] forKey:@"BASH_ENV"];

	NSString *line = [ts lineForLocation:[textView caret]];
	if (line)
		[env setObject:line forKey:@"TM_CURRENT_LINE"];

	NSString *word = [ts wordAtLocation:[textView caret] range:nil acceptAfter:YES];
	if (word)
		[env setObject:word forKey:@"TM_CURRENT_WORD" ];

	NSURL *url = [[textView.document environment] baseURL];
	if ([url isFileURL])
		[env setObject:[url path] forKey:@"TM_PROJECT_DIRECTORY"];
	[env setObject:[url absoluteString] forKey:@"TM_PROJECT_URL"];

	url = [textView.document fileURL];
	if (url) {
		if ([url isFileURL]) {
			[env setObject:[[url path] stringByDeletingLastPathComponent] forKey:@"TM_DIRECTORY"];
			[env setObject:[url path] forKey:@"TM_FILEPATH"];
		}
		[env setObject:[[url path] lastPathComponent] forKey:@"TM_FILENAME"];
		[env setObject:[url absoluteString] forKey:@"TM_FILEURL"];
	}

	[env setObject:NSFullUserName() forKey:@"TM_FULLNAME"];
	[env setObject:[NSString stringWithFormat:@"%li", [ts columnOffsetAtLocation:[textView caret]]] forKey:@"TM_LINE_INDEX"];
	[env setObject:[NSString stringWithFormat:@"%li", [textView currentLine]] forKey:@"TM_LINE_NUMBER"];

	NSString *scope = [[textView scopesAtLocation:[textView caret]] componentsJoinedByString:@" "];
	if (scope)
		[env setObject:scope forKey:@"TM_SCOPE"];

	NSRange sel = [textView selectedRange];
	if (sel.length > 0) {
		[env setObject:[NSString stringWithFormat:@"%li", [ts columnAtLocation:sel.location]] forKey:@"TM_INPUT_START_COLUMN"];
		[env setObject:[NSString stringWithFormat:@"%li", [ts columnAtLocation:NSMaxRange(sel)]] forKey:@"TM_INPUT_END_COLUMN"];

		[env setObject:[NSString stringWithFormat:@"%li", [ts columnAtLocation:sel.location]] forKey:@"TM_INPUT_START_LINE_INDEX"];
		[env setObject:[NSString stringWithFormat:@"%li", [ts lineNumberAtLocation:sel.location]] forKey:@"TM_INPUT_START_LINE"];

		[env setObject:[NSString stringWithFormat:@"%li", [ts lineNumberAtLocation:NSMaxRange(sel)]] forKey:@"TM_INPUT_END_LINE"];
		[env setObject:[NSString stringWithFormat:@"%li", [ts columnAtLocation:NSMaxRange(sel)]] forKey:@"TM_INPUT_END_LINE_INDEX"];

		[env setObject:[[ts string] substringWithRange:sel] forKey:@"TM_SELECTED_TEXT"];
	}

	// FIXME: TM_SELECTED_FILES
	// FIXME: TM_SELECTED_FILE

	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];

	if ([defs integerForKey:@"expandtab"] == NSOnState)
		[env setObject:@"YES" forKey:@"TM_SOFT_TABS" ];
	else
		[env setObject:@"NO" forKey:@"TM_SOFT_TABS" ];

	[env setObject:[defs stringForKey:@"shiftwidth"] forKey:@"TM_TAB_SIZE"];
	[env setObject:NSHomeDirectory() forKey:@"HOME"];

	/*
	 * Global (static) environment variables.
	 */
	[env addEntriesFromDictionary:[defs dictionaryForKey:@"environment"]];

	/*
	 * shellVariables from bundle preferences
	 */
	NSDictionary *shellVariables = [[ViLanguageStore defaultStore] preferenceItem:@"shellVariables"];
	NSString *bestMatchingScope = [textView bestMatchingScope:[shellVariables allKeys] atLocation:[textView caret]];

	if (bestMatchingScope) {
		id vars = [shellVariables objectForKey:bestMatchingScope];
		if ([vars isKindOfClass:[NSArray class]]) {
			for (NSDictionary *var in vars) {
				if ([var isKindOfClass:[NSDictionary class]]) {
					NSString *varName = [var objectForKey:@"name"];
					NSString *varValue = [var objectForKey:@"value"];
					if ([varName isKindOfClass:[NSString class]] &&
					    [varValue isKindOfClass:[NSString class]])
						[env setObject:varValue forKey:varName];
				}
			}
		}
	}
}

- (id)initWithPath:(NSString *)aPath
{
	self = [super init];
	if (self) {
		info = [NSDictionary dictionaryWithContentsOfFile:aPath];
		if ([info objectForKey:@"isDelta"]) {
			INFO(@"delta bundles not implemented, at %@", aPath);
			return nil;
		}

		languages = [[NSMutableArray alloc] init];
		preferences = [[NSMutableArray alloc] init];
		cachedPreferences = [[NSMutableDictionary alloc] init];
		uuids = [[NSMutableDictionary alloc] init];
		items = [[NSMutableArray alloc] init];
		path = [aPath stringByDeletingLastPathComponent];
	}

	return self;
}

- (NSString *)supportPath
{
	return [path stringByAppendingPathComponent:@"Support"];
}

- (NSString *)name
{
	return [info objectForKey:@"name"];
}

- (void)addLanguage:(ViLanguage *)lang
{
	[languages addObject:lang];
}

- (void)addPreferences:(NSMutableDictionary *)prefs
{
	if ([prefs isKindOfClass:[NSDictionary class]]) {
		[ViBundle normalizePreference:prefs intoDictionary:[prefs objectForKey:@"settings"]];
		[preferences addObject:prefs];
	}
}

- (NSDictionary *)preferenceItems:(NSArray *)prefsNames
{
	NSMutableDictionary *prefsForScope = [[NSMutableDictionary alloc] init];

	NSDictionary *prefs;
	for (prefs in preferences) {
		NSDictionary *settings = [prefs objectForKey:@"settings"];

		NSMutableDictionary *prefsValues = nil;
		for (NSString *prefsName in prefsNames) {
			id prefsValue = [settings objectForKey:prefsName];
			if (prefsValue) {
				if (prefsValues == nil)
					prefsValues = [[NSMutableDictionary alloc] init];
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
	NSMutableDictionary *prefsForScope = [[NSMutableDictionary alloc] init];

	NSDictionary *prefs;
	for (prefs in preferences) {
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

- (void)addSnippet:(NSDictionary *)desc
{
	ViBundleSnippet *snippet = [(ViBundleSnippet *)[ViBundleSnippet alloc] initFromDictionary:desc inBundle:self];
	if (snippet) {
		[items addObject:snippet];
		[uuids setObject:snippet forKey:[snippet uuid]];
	}
}

- (void)addCommand:(NSMutableDictionary *)desc
{
	ViBundleCommand *command = [(ViBundleCommand *)[ViBundleCommand alloc] initFromDictionary:desc inBundle:self];
	if (command) {
		[items addObject:command];
		[uuids setObject:command forKey:[command uuid]];
	}
}

- (NSMenu *)submenu:(NSDictionary *)menuLayout
           withName:(NSString *)name
         inMainMenu:(NSDictionary *)mainMenu
          forScopes:(NSArray *)scopes
       enabledItems:(NSUInteger *)enabledItemsPtr
       hasSelection:(BOOL)hasSelection
               font:(NSFont *)aFont
{
	int matches = 0;
	NSMenu *menu = [[NSMenu alloc] initWithTitle:name];
	[menu setAutoenablesItems:NO];
	NSDictionary *submenus = [mainMenu objectForKey:@"submenus"];

	for (NSString *uuid in [menuLayout objectForKey:@"items"]) {
		id op;
		NSMenuItem *item;

		if ([uuid isEqualToString:@"------------------------------------"]) {
			item = [NSMenuItem separatorItem];
			[menu addItem:item];
		} else if ((op = [uuids objectForKey:uuid]) != nil) {
			SEL selector = NULL;
			if ([op isKindOfClass:[ViBundleItem class]]) {
				NSString *scope = [op scope];
				if (scope == nil || [scope matchesScopes:scopes] > 0) {
					matches++;
					selector = @selector(performBundleItem:);
				}
				/* otherwise selector is NULL => disabled menu item */

				/* Replace "Thing / Selection" depending on hasSelection.
				 */
				NSMutableString *title = [[op name] mutableCopy];
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
					view = [[ViCommandMenuItemView alloc] initWithTitle:[op name]
										 tabTrigger:tabTrigger
										       font:aFont];
					[item setView:view];
				}
			} else
				INFO(@"unhandled bundle item %@", op);
		} else {
			NSDictionary *submenuLayout = [submenus objectForKey:uuid];
			if (submenuLayout) {
				NSUInteger submatches = 0;
				NSMenu *submenu = [self submenu:submenuLayout
				                       withName:[submenuLayout objectForKey:@"name"]
				                     inMainMenu:mainMenu
				                      forScopes:scopes
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
				INFO(@"missing menu item %@ in bundle %@", uuid, [self name]);
		}

	}

	if (enabledItemsPtr)
		*enabledItemsPtr = matches;

	return menu;
}

- (NSMenu *)menuForScopes:(NSArray *)scopes
             hasSelection:(BOOL)hasSelection
                     font:(NSFont *)aFont
{
	NSDictionary *mainMenu = [info objectForKey:@"mainMenu"];
	if (mainMenu == nil || ![mainMenu isKindOfClass:[NSDictionary class]])
		return nil;

	NSUInteger matches = 0;
	NSMenu *menu = [self submenu:mainMenu
	                    withName:[self name]
	                  inMainMenu:mainMenu
	                   forScopes:scopes
	                enabledItems:&matches
	                hasSelection:hasSelection
				font:aFont];

	return matches == 0 ? nil : menu;
}

@end

