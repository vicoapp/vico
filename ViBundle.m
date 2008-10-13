#import "ViBundle.h"
#import "logging.h"

@implementation ViBundle

@synthesize languages;

- (id)initWithPath:(NSString *)aPath
{
	self = [super init];
	if (self)
	{
		languages = [[NSMutableArray alloc] init];
		preferences = [[NSMutableArray alloc] init];
		cachedPreferences = [[NSMutableDictionary alloc] init];
		info = [NSDictionary dictionaryWithContentsOfFile:aPath];
	}
	
	return self;
}

- (NSString *)name
{
	return [info objectForKey:@"name"];
}

- (void)addLanguage:(ViLanguage *)lang
{
	[languages addObject:lang];
}

- (void)addPreferences:(NSDictionary *)prefs
{
	[preferences addObject:prefs];
}

- (NSDictionary *)preferenceItems:(NSString *)prefsName
{
	NSMutableDictionary *prefsForScope = [cachedPreferences objectForKey:prefsName];
	if (prefsForScope)
		return prefsForScope;

	prefsForScope = [[NSMutableDictionary alloc] init];
	[cachedPreferences setObject:prefsForScope forKey:prefsName];
	
	NSDictionary *prefs;
	for (prefs in preferences)
	{
		NSString *scope = [prefs objectForKey:@"scope"];
		NSDictionary *settings = [prefs objectForKey:@"settings"];
		id prefsValue = [settings objectForKey:prefsName];
		if (prefsValue)
		{
			NSString *s;
			for (s in [scope componentsSeparatedByString:@", "])
			{
				[prefsForScope setObject:prefsValue forKey:s];
			}
		}
	}

	return prefsForScope;
}

@end

