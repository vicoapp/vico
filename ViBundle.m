#import "NSString-scopeSelector.h"
#import "ViBundle.h"
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
			for (NSString *s in [scope componentsSeparatedByString:@", "]) {
				NSMutableDictionary *oldPrefsValues = [prefsForScope objectForKey:s];
				if (oldPrefsValues)
					[oldPrefsValues addEntriesFromDictionary:prefsValues];
				else
					[prefsForScope setObject:prefsValues forKey:s];
			}
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
			for (NSString *s in [scope componentsSeparatedByString:@", "])
				[prefsForScope setObject:prefsValue forKey:s];
		}
	}

	return prefsForScope;
}

- (void)addSnippet:(NSDictionary *)snippet
{
	[snippets addObject:snippet];
}

- (void)addCommand:(NSMutableDictionary *)command
{
	[command setObject:self forKey:@"bundle"];
	[commands addObject:command];
}

- (NSString *)tabTrigger:(NSString *)name matchingScopes:(NSArray *)scopes
{
        NSDictionary *snippet;
        for (snippet in snippets)
        {
                if ([[snippet objectForKey:@"tabTrigger"] isEqualToString:name])
                {
                        // check scopes
                        NSArray *scopeSelectors = [[snippet objectForKey:@"scope"] componentsSeparatedByString:@", "];
                        NSString *scopeSelector;
                        for (scopeSelector in scopeSelectors)
                        {
                                if ([scopeSelector matchesScopes:scopes] > 0)
                                {
                                        return [snippet objectForKey:@"content"];
                                }
                        }
                }
        }
        
        return nil;
}

@end

