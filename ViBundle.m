#import "NSString-scopeSelector.h"
#import "ViBundle.h"
#import "ViBundleCommand.h"
#import "ViBundleSnippet.h"
#import "logging.h"

@implementation ViBundle

@synthesize languages;
@synthesize commands;
@synthesize path;

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

+ (void)normalizePreference:(NSDictionary *)preference intoDictionary:(NSMutableDictionary *)normalizedPreference
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
		snippets = [[NSMutableArray alloc] init];
		commands = [[NSMutableArray alloc] init];
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
	ViBundleSnippet *snippet = [[ViBundleSnippet alloc] initFromDictionary:desc inBundle:self];
	if (snippet) {
		[snippets addObject:snippet];
		[uuids setObject:snippet forKey:[snippet uuid]];
	}
}

- (void)addCommand:(NSMutableDictionary *)desc
{
	ViBundleCommand *command = [[ViBundleCommand alloc] initFromDictionary:desc inBundle:self];
	if (command) {
		[commands addObject:command];
		[uuids setObject:command forKey:[command uuid]];
	}
}

- (ViBundleCommand *)commandWithKey:(unichar)keycode andFlags:(unsigned int)flags matchingScopes:(NSArray *)scopes
{
	for (ViBundleCommand *command in commands)
                if ([command keycode] == keycode && [command keyflags] == flags) {
			NSString *scope = [command scope];
			if (scope == nil || [scope matchesScopes:scopes] > 0)
				return command;
		}

	return nil;
}

- (NSString *)tabTrigger:(NSString *)name matchingScopes:(NSArray *)scopes
{
        for (ViBundleSnippet *snippet in snippets)
                if ([[snippet tabTrigger] isEqualToString:name] &&
		    [[snippet scope] matchesScopes:scopes] > 0)
			return [snippet content];

        return nil;
}

- (NSMenu *)submenu:(NSDictionary *)menuLayout withName:(NSString *)name forScopes:(NSArray *)scopes
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
				ViBundleCommand *command = op;
				NSString *scope = [command scope];
				if (scope == nil || [scope matchesScopes:scopes] > 0) {
					matches++;
					if ([op isMemberOfClass:[ViBundleCommand class]])
						selector = @selector(performBundleCommand:);
					else if ([op isMemberOfClass:[ViBundleSnippet class]])
						selector = @selector(performBundleSnippet:);
				}
				/* otherwise selector is NULL => disabled menu item */
	
				item = [menu addItemWithTitle:[command name]
						       action:selector
						keyEquivalent:[command keyEquivalent]];
				[item setKeyEquivalentModifierMask:[command modifierMask]];
				[item setRepresentedObject:command];
			} else
				INFO(@"unhandled bundle item %@", op);
		} else {
			NSDictionary *submenuLayout = [submenus objectForKey:uuid];
			if (submenuLayout) {
				NSMenu *submenu = [self submenu:submenuLayout withName:[submenuLayout objectForKey:@"name"] forScopes:scopes];
				if (submenu) {
					item = [menu addItemWithTitle:[submenuLayout objectForKey:@"name"] action:NULL keyEquivalent:@""];
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

