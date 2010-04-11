#import "ViLanguageStore.h"
#import "ViBundle.h"
#import "logging.h"

@implementation ViLanguageStore

static ViLanguageStore *defaultStore = nil;

- (id)init
{
	self = [super init];
	if (self)
	{
		languages = [[NSMutableDictionary alloc] init];
		cachedPreferences = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)addBundlesFromBundleDirectory:(NSString *)aPath
{
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

		ViBundle *bundle = [[ViBundle alloc] initWithPath:infoPath];

		NSString *syntaxPath = [NSString stringWithFormat:@"%@/%@/Syntaxes", aPath, subdir];
		NSArray *syntaxfiles = [[NSFileManager defaultManager] directoryContentsAtPath:syntaxPath];
		NSString *syntaxfile;
		for (syntaxfile in syntaxfiles)
		{
			if ([syntaxfile hasSuffix:@".tmLanguage"] || [syntaxfile hasSuffix:@".plist"])
			{
				ViLanguage *language = [[ViLanguage alloc] initWithPath:[NSString stringWithFormat:@"%@/%@", syntaxPath, syntaxfile]];
				[bundle addLanguage:language];
				[languages setObject:language forKey:[language name]];
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
				[bundle addPreferences:prefs];
			}
		}

		NSString *path = [NSString stringWithFormat:@"%@/%@/Snippets", aPath, subdir];
		NSArray *files = [[NSFileManager defaultManager] directoryContentsAtPath:path];
		NSString *file;
		for (file in files)
		{
			if ([file hasSuffix:@".tmSnippet"] || [file hasSuffix:@".plist"])
			{
				NSDictionary *snippet = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/%@", path, file]];
				[bundle addSnippet:snippet];
			}
		}

		path = [NSString stringWithFormat:@"%@/%@/Commands", aPath, subdir];
		files = [[NSFileManager defaultManager] directoryContentsAtPath:path];
		for (file in files)
		{
			if ([file hasSuffix:@".tmCommand"] || [file hasSuffix:@".plist"])
			{
				NSMutableDictionary *command = [NSMutableDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/%@", path, file]];
				[bundle addCommand:command];
			}
		}

		[bundles addObject:bundle];
	}
}

- (void)initLanguages
{
	languages = [[NSMutableDictionary alloc] init];
	bundles = [[NSMutableArray alloc] init];

	DEBUG(@"start initializing languages");
	[self addBundlesFromBundleDirectory:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Resources/Bundles"]];
#if 0
	[self addBundlesFromBundleDirectory:@"/Library/Application Support/TextMate/Bundles"];
	[self addBundlesFromBundleDirectory:[@"~/Library/Application Support/TextMate/Pristine Copy/Bundles" stringByExpandingTildeInPath]];
	[self addBundlesFromBundleDirectory:[@"~/Library/Application Support/TextMate/Bundles" stringByExpandingTildeInPath]];
#endif
	[self addBundlesFromBundleDirectory:[@"~/Library/Application Support/Vizard/Bundles" stringByExpandingTildeInPath]];
	DEBUG(@"finished initializing languages");
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

- (ViBundle *)bundleForFirstLine:(NSString *)firstLine language:(ViLanguage **)languagePtr
{
	ViBundle *bundle;
	for (bundle in bundles) {
		ViLanguage *language;
		for (language in [bundle languages]) {
			NSString *firstLineMatch = [language firstLineMatch];
			if (firstLineMatch == nil)
				continue;

			ViRegexp *rx = [ViRegexp regularExpressionWithString:firstLineMatch];
			if ([rx matchInString:firstLine]) {
				DEBUG(@"Using language %@ for first line [%@]", [language name], firstLine);
				if (languagePtr)
					*languagePtr = language;
				DEBUG(@"Using bundle %@", [bundle name]);
				return bundle;
			}
		}
	}
	DEBUG(@"No language matching first line [%@]", firstLine);
	return nil;
}

- (ViBundle *)bundleForFilename:(NSString *)aPath language:(ViLanguage **)languagePtr
{
	NSCharacterSet *pathSeparators = [NSCharacterSet characterSetWithCharactersInString:@"./"];
	ViBundle *bundle;
	for (bundle in bundles) {
		ViLanguage *language;

		for (language in [bundle languages]) {
			NSArray *fileTypes = [language fileTypes];
			NSString *fileType;

			for (fileType in fileTypes) {
				unsigned path_len = [aPath length];
				unsigned ftype_len = [fileType length];

				if ([aPath hasSuffix:fileType] &&
				    (path_len == ftype_len ||
				     [pathSeparators characterIsMember:[aPath characterAtIndex:path_len - ftype_len - 1]])) {
					DEBUG(@"Using language %@ for file %@", [language name], aPath);
					if (languagePtr)
						*languagePtr = language;
					DEBUG(@"Using bundle %@", [bundle name]);
					return bundle;
				}
			}
		}
	}

	DEBUG(@"No language found for file %@", aPath);
	return nil;
}

- (ViBundle *)bundleForLanguage:(NSString *)languageName language:(ViLanguage **)languagePtr
{
	ViBundle *bundle;
	for (bundle in bundles) {
		ViLanguage *language;
		for (language in [bundle languages]) {
			if ([[language displayName] isEqualToString:languageName]) {
				if (languagePtr)
					*languagePtr = language;

				return bundle;
			}
		}
	}
	
	INFO(@"language '%@' not found", languageName);
	return nil;
}

- (ViBundle *)defaultBundleLanguage:(ViLanguage **)languagePtr
{
	return [self bundleForLanguage:@"Plain Text" language:languagePtr];
}

- (ViLanguage *)languageWithScope:(NSString *)scopeName
{
	return [languages objectForKey:scopeName];
}

- (NSArray *)allLanguageNames
{
	NSMutableArray *langnames = [[NSMutableArray alloc] init];
	ViLanguage *lang;
	for (lang in [languages allValues])
		[langnames addObject:[lang displayName]];

	return langnames;
}

- (NSArray *)allBundles
{
	return bundles;
}

- (NSDictionary *)preferenceItems:(NSString *)prefsName includeAllSettings:(BOOL)includeAllSettings
{
	NSMutableDictionary *result = [cachedPreferences objectForKey:prefsName];
	if (result)
		return result;

	result = [[NSMutableDictionary alloc] init];
	[cachedPreferences setObject:result forKey:prefsName];
	
	ViBundle *bundle;
	for (bundle in bundles) {
		NSDictionary *p = [bundle preferenceItems:prefsName includeAllSettings:includeAllSettings];
		if (p)
			[result addEntriesFromDictionary:p];
	}

	return result;
}

- (NSDictionary *)preferenceItems:(NSString *)prefsName
{
	return [self preferenceItems:prefsName includeAllSettings:NO];
}

- (NSString *)tabTrigger:(NSString *)name matchingScopes:(NSArray *)scopes;
{
	ViBundle *bundle;
	for (bundle in bundles) {
		NSString *s = [bundle tabTrigger:name matchingScopes:scopes];
		if (s)
			return s;
	}

	return nil;
}

@end
