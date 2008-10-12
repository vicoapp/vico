#import "ViLanguageStore.h"
#import "logging.h"

@implementation ViLanguageStore

static ViLanguageStore *defaultStore = nil;

- (void)addBundlesFromBundleDirectory:(NSString *)aPath
{
	INFO(@"checking directory %@", aPath);
	BOOL isDirectory = NO;
	if (![[NSFileManager defaultManager] fileExistsAtPath:aPath isDirectory:&isDirectory] || !isDirectory)
		return;

	NSArray *subdirs = [[NSFileManager defaultManager] directoryContentsAtPath:aPath];
	NSString *subdir;
	for (subdir in subdirs)
	{
		NSString *infoPath = [NSString stringWithFormat:@"%@/%@/info.plist", aPath, subdir];
		if (![[NSFileManager defaultManager] fileExistsAtPath:infoPath])
			continue;
		
		NSMutableDictionary *bundle = [[NSMutableDictionary alloc] init];
		[bundle setObject:[NSDictionary dictionaryWithContentsOfFile:infoPath] forKey:@"info"];
		// NSLog(@"=== parsing bundle [%@]", [[bundle objectForKey:@"info"] objectForKey:@"name"]);

		[bundle setObject:[NSString stringWithFormat:@"%@/%@", aPath, subdir] forKey:@"path"];

		NSString *syntaxPath = [NSString stringWithFormat:@"%@/%@/Syntaxes", aPath, subdir];
		NSArray *syntaxfiles = [[NSFileManager defaultManager] directoryContentsAtPath:syntaxPath];
		NSString *syntaxfile;
		for (syntaxfile in syntaxfiles)
		{
			if ([syntaxfile hasSuffix:@".tmLanguage"] || [syntaxfile hasSuffix:@".plist"])
			{
				ViLanguage *language = [[ViLanguage alloc] initWithPath:[NSString stringWithFormat:@"%@/%@", syntaxPath, syntaxfile]];
				NSMutableArray *languageList = [bundle objectForKey:@"languages"];
				if (languageList == nil)
				{
					languageList = [[NSMutableArray alloc] init];
					[bundle setObject:languageList forKey:@"languages"];
				}
				// NSLog(@"  adding syntax for language [%@]", [language name]);
				[languages setObject:language forKey:[language name]];
				[languageList addObject:language];
			}
		}

		NSString *prefsPath = [NSString stringWithFormat:@"%@/%@/Preferences", aPath, subdir];
		NSArray *prefsfiles = [[NSFileManager defaultManager] directoryContentsAtPath:prefsPath];
		NSString *prefsfile;
		for (prefsfile in prefsfiles)
		{
			if ([prefsfile hasSuffix:@".plist"])
			{
				NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/%@", prefsPath, prefsfile]];
				NSMutableArray *prefsList = [bundle objectForKey:@"preferences"];
				if (prefsList == nil)
				{
					prefsList = [[NSMutableArray alloc] init];
					[bundle setObject:prefsList forKey:@"preferences"];
				}
				// NSLog(@"  adding preferences for [%@]", [prefs objectForKey:@"name"]);
				[prefsList addObject:prefs];
			}
		}

		[bundles addObject:bundle];
	}
}

- (void)initLanguages
{
	languages = [[NSMutableDictionary alloc] init];
	bundles = [[NSMutableArray alloc] init];

	NSLog(@"start initializing languages");
	[self addBundlesFromBundleDirectory:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Resources/Bundles"]];
#if 0
	[self addBundlesFromBundleDirectory:@"/Library/Application Support/TextMate/Bundles"];
	[self addBundlesFromBundleDirectory:[@"~/Library/Application Support/TextMate/Pristine Copy/Bundles" stringByExpandingTildeInPath]];
	[self addBundlesFromBundleDirectory:[@"~/Library/Application Support/TextMate/Bundles" stringByExpandingTildeInPath]];
#endif
	[self addBundlesFromBundleDirectory:[@"~/Library/Application Support/Vizard/Bundles" stringByExpandingTildeInPath]];
	NSLog(@"finished initializing languages");
}

+ (ViLanguageStore *)defaultStore
{
	if (defaultStore == nil)
	{
		defaultStore = [[ViLanguageStore alloc] init];
		[defaultStore initLanguages];
	}
	return defaultStore;
}

- (NSMutableDictionary *)bundleForFirstLine:(NSString *)firstLine language:(ViLanguage **)languagePtr
{
	NSMutableDictionary *bundle;
	for (bundle in bundles)
	{
		ViLanguage *language;
		for (language in [bundle objectForKey:@"languages"])
		{
			NSString *firstLineMatch = [language firstLineMatch];
			if (firstLineMatch == nil)
				continue;

			if ([firstLine rangeOfRegularExpressionString:firstLineMatch].location != NSNotFound)
			{
				NSLog(@"Using language %@ for first line [%@]", [language name], firstLine);
				if (languagePtr)
					*languagePtr = language;
				NSLog(@"Using bundle %@", [[bundle objectForKey:@"info"] objectForKey:@"name"]);
				return bundle;
			}
		}
	}
	NSLog(@"No language matching first line [%@]", firstLine);
	return nil;
}

- (NSMutableDictionary *)bundleForFilename:(NSString *)aPath language:(ViLanguage **)languagePtr
{
	NSCharacterSet *pathSeparators = [NSCharacterSet characterSetWithCharactersInString:@"./"];
	NSMutableDictionary *bundle;
	for (bundle in bundles)
	{
		ViLanguage *language;
		for (language in [bundle objectForKey:@"languages"])
		{
			NSArray *fileTypes = [language fileTypes];
			NSString *fileType;
			for (fileType in fileTypes)
			{
				unsigned path_len = [aPath length];
				unsigned ftype_len = [fileType length];
				if ([aPath hasSuffix:fileType] &&
				    (path_len == ftype_len ||
				     [pathSeparators characterIsMember:[aPath characterAtIndex:path_len - ftype_len - 1]]))
				{
					NSLog(@"Using language %@ for file %@", [language name], aPath);
					if (languagePtr)
						*languagePtr = language;
					NSLog(@"Using bundle %@", [[bundle objectForKey:@"info"] objectForKey:@"name"]);
					return bundle;
				}
			}
		}
	}
	NSLog(@"No language found for file %@", aPath);
	return nil;
}

- (NSMutableDictionary *)bundleForLanguage:(NSString *)languageName language:(ViLanguage **)languagePtr
{
	NSMutableDictionary *bundle;
	for (bundle in bundles)
	{
		ViLanguage *language;
		for (language in [bundle objectForKey:@"languages"])
		{
			if ([[language displayName] isEqualToString:languageName])
			{
				if (languagePtr)
					*languagePtr = language;
	
				return bundle;
			}
		}
	}
	
	INFO(@"language '%@' not found", languageName);
	return nil;
}

- (NSMutableDictionary *)defaultBundleLanguage:(ViLanguage **)languagePtr
{
	return [self bundleForLanguage:@"Plain Text" language:languagePtr];
}

- (NSMutableDictionary *)allSmartTypingPairs
{
	if (allSmartTypingPairs)
		return allSmartTypingPairs;

	NSLog(@"begin collecting all smart typing pairs");
	allSmartTypingPairs = [[NSMutableDictionary alloc] init];
	NSMutableDictionary *bundle;
	for (bundle in bundles)
	{
		NSDictionary *prefs;
		for (prefs in [bundle objectForKey:@"preferences"])
		{
			NSDictionary *settings = [prefs objectForKey:@"settings"];
			if (settings == nil)
				continue;
			NSArray *smartTypingPairs = [settings objectForKey:@"smartTypingPairs"];
			if (smartTypingPairs == nil)
				continue;

			NSString *scope;
			for (scope in [[prefs objectForKey:@"scope"] componentsSeparatedByString:@", "])
			{
				[allSmartTypingPairs setObject:smartTypingPairs forKey:scope];
			}
		}
	}
	NSLog(@"finished collecting all smart typing pairs, found %i preferences", [allSmartTypingPairs count]);

	return allSmartTypingPairs;
}

- (ViLanguage *)languageWithScope:(NSString *)scopeName
{
	return [languages objectForKey:scopeName];
}

- (NSArray *)allLanguages
{
	NSMutableArray *langnames = [[NSMutableArray alloc] init];
	ViLanguage *lang;
	for (lang in [languages allValues])
	{
		[langnames addObject:[lang displayName]];
	}
	return langnames;
}

@end
