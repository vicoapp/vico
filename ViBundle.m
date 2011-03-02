#import "NSString-scopeSelector.h"
#import "ViBundle.h"
#import "ViBundleCommand.h"
#import "ViBundleSnippet.h"
#import "ViTabTriggerMenuItemView.h"
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

	return [NSColor colorWithCalibratedRed:(float)r/255.0 green:(float)g/255.0 blue:(float)b/255.0 alpha:(float)a/255.0];
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
			[normalizedPreference setObject:color forKey:NSForegroundColorAttributeName];
	}

	if ((value = [settings objectForKey:@"background"]) != nil) {
		if ((color = [self hashRGBToColor:value]) != nil)
			[normalizedPreference setObject:color forKey:NSBackgroundColorAttributeName];
	}

	if ((value = [settings objectForKey:@"fontStyle"]) != nil) {
		if ([value rangeOfString:@"underline"].location != NSNotFound)
			[normalizedPreference setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle] forKey:NSUnderlineStyleAttributeName];
		if ([value rangeOfString:@"italic"].location != NSNotFound)
			[normalizedPreference setObject:[NSNumber numberWithFloat:0.3] forKey:NSObliquenessAttributeName];
		if ([value rangeOfString:@"bold"].location != NSNotFound)
			[normalizedPreference setObject:[NSNumber numberWithFloat:-3.0] forKey:NSStrokeWidthAttributeName];
	}

	if ((value = [settings objectForKey:@"underline"]) != nil)
		[normalizedPreference setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle] forKey:NSUnderlineStyleAttributeName];

	if ((value = [settings objectForKey:@"italic"]) != nil)
		[normalizedPreference setObject:[NSNumber numberWithFloat:0.3] forKey:NSObliquenessAttributeName];

	if ((value = [settings objectForKey:@"bold"]) != nil)
		[normalizedPreference setObject:[NSNumber numberWithFloat:-3.0] forKey:NSStrokeWidthAttributeName];
}

+ (void)setupEnvironment:(NSMutableDictionary *)env
             forTextView:(ViTextView *)textView
{
	NSString *supportPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Resources/Support"];
	[env setObject:supportPath forKey:@"TM_SUPPORT_PATH"];

	[env setObject:[supportPath stringByAppendingPathComponent:@"lib/bash_init.sh"] forKey:@"BASH_ENV"];

	NSString *line = [[textView textStorage] lineForLocation:[textView caret]];
	if (line)
		[env setObject:line forKey:@"TM_CURRENT_LINE"];

	NSString *word = [[textView textStorage] wordAtLocation:[textView caret] range:nil acceptAfter:YES];
	if (word)
		[env setObject:word forKey:@"TM_CURRENT_WORD" ];

	NSURL *url = [[[textView delegate] environment] baseURL];
	if ([url isFileURL])
		[env setObject:[url path] forKey:@"TM_PROJECT_DIRECTORY"];
	[env setObject:[url absoluteString] forKey:@"TM_PROJECT_URL"];

	url = [[textView delegate] fileURL];
	if (url) {
		if ([url isFileURL]) {
			[env setObject:[[url path] stringByDeletingLastPathComponent] forKey:@"TM_DIRECTORY"];
			[env setObject:[url path] forKey:@"TM_FILEPATH"];
		}
		[env setObject:[[url path] lastPathComponent] forKey:@"TM_FILENAME"];
		[env setObject:[url absoluteString] forKey:@"TM_FILEURL"];
	}

	[env setObject:NSFullUserName() forKey:@"TM_FULLNAME"];
	[env setObject:[NSString stringWithFormat:@"%li", [[textView textStorage] columnOffsetAtLocation:[textView caret]]] forKey:@"TM_LINE_INDEX"];
	[env setObject:[NSString stringWithFormat:@"%li", [textView currentLine]] forKey:@"TM_LINE_NUMBER"];

	NSString *scope = [[textView scopesAtLocation:[textView caret]] componentsJoinedByString:@" "];
	if (scope)
		[env setObject:scope forKey:@"TM_SCOPE"];

	NSRange sel = [textView selectedRange];
	if (sel.length > 0) {
		[env setObject:[NSString stringWithFormat:@"%li", [[textView textStorage] columnAtLocation:sel.location]] forKey:@"TM_INPUT_START_COLUMN"];
		[env setObject:[NSString stringWithFormat:@"%li", [[textView textStorage] columnAtLocation:NSMaxRange(sel)]] forKey:@"TM_INPUT_END_COLUMN"];

		[env setObject:[NSString stringWithFormat:@"%li", [[textView textStorage] columnAtLocation:sel.location]] forKey:@"TM_INPUT_START_LINE_INDEX"];
		[env setObject:[NSString stringWithFormat:@"%li", [[textView textStorage] lineNumberAtLocation:sel.location]] forKey:@"TM_INPUT_START_LINE"];

		[env setObject:[NSString stringWithFormat:@"%li", [[textView textStorage] lineNumberAtLocation:NSMaxRange(sel)]] forKey:@"TM_INPUT_END_LINE"];
		[env setObject:[NSString stringWithFormat:@"%li", [[textView textStorage] columnAtLocation:NSMaxRange(sel)]] forKey:@"TM_INPUT_END_LINE_INDEX"];

		[env setObject:[[[textView textStorage] string] substringWithRange:sel] forKey:@"TM_SELECTED_TEXT"];
	}

	// FIXME: TM_SELECTED_FILES
	// FIXME: TM_SELECTED_FILE

	if ([[NSUserDefaults standardUserDefaults] integerForKey:@"expandtab"] == NSOnState)
		[env setObject:@"YES" forKey:@"TM_SOFT_TABS" ];
	else
		[env setObject:@"NO" forKey:@"TM_SOFT_TABS" ];

	[env setObject:[[NSUserDefaults standardUserDefaults] stringForKey:@"shiftwidth"] forKey:@"TM_TAB_SIZE"];
	[env setObject:NSHomeDirectory() forKey:@"HOME"];

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
	[ViBundle normalizePreference:prefs intoDictionary:[prefs objectForKey:@"settings"]];
	[preferences addObject:prefs];
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
          forScopes:(NSArray *)scopes
{
	int matches = 0;
	NSMenu *menu = [[NSMenu alloc] initWithTitle:name];
	NSDictionary *submenus = [menuLayout objectForKey:@"submenus"];

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

				item = [menu addItemWithTitle:[op name]
						       action:selector
						keyEquivalent:[op keyEquivalent]];
				[item setKeyEquivalentModifierMask:[op modifierMask]];
				[item setRepresentedObject:op];

				NSString *tabTrigger = [op tabTrigger];
				if ([tabTrigger length] > 0) {
					/* Set a special view for drawing the tab trigger. */
					ViTabTriggerMenuItemView *view;
					view = [[ViTabTriggerMenuItemView alloc] initWithTitle:[op name]
					                                            tabTrigger:tabTrigger];
					[item setView:view];
				}
			} else
				DEBUG(@"unhandled bundle item %@", op);
		} else {
			NSDictionary *submenuLayout = [submenus objectForKey:uuid];
			if (submenuLayout) {
				NSMenu *submenu = [self submenu:submenuLayout
				                       withName:[submenuLayout objectForKey:@"name"]
				                      forScopes:scopes];
				if (submenu) {
					item = [menu addItemWithTitle:[submenuLayout objectForKey:@"name"]
					                       action:NULL
					                keyEquivalent:@""];
					[item setSubmenu:submenu];
				}
			} else
				DEBUG(@"missing menu item %@ in bundle %@", uuid, [self name]);
		}

	}

	return matches == 0 ? nil : menu;
}

- (NSMenu *)menuForScopes:(NSArray *)scopes
{
	NSDictionary *mainMenu = [info objectForKey:@"mainMenu"];
	if (mainMenu == nil)
		return nil;

	NSMenu *menu = [self submenu:mainMenu withName:[self name] forScopes:scopes];

	return menu;

}

@end

