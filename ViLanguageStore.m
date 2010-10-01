#import "ViLanguageStore.h"
#import "ViBundle.h"
#import "logging.h"

@implementation ViLanguageStore

static ViLanguageStore *defaultStore = nil;
static NSString *bundlesDirectory = nil;

+ (NSString *)bundlesDirectory
{
	if (bundlesDirectory == nil)
		bundlesDirectory = [@"~/Library/Application Support/Vibrant/Bundles" stringByExpandingTildeInPath];
	return bundlesDirectory;
}

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

- (BOOL)loadBundleFromDirectory:(NSString *)bundleDirectory
{
	NSFileManager *fm = [NSFileManager defaultManager];

	NSString *infoPath = [NSString stringWithFormat:@"%@/info.plist", bundleDirectory];
	if (![fm fileExistsAtPath:infoPath])
		return NO;

	ViBundle *bundle = [[ViBundle alloc] initWithPath:infoPath];
	if (bundle == nil)
		return NO;

	NSString *dir = [NSString stringWithFormat:@"%@/Syntaxes", bundleDirectory];
	NSString *file;
	for (file in [fm directoryContentsAtPath:dir]) {
		if ([file hasSuffix:@".tmLanguage"] || [file hasSuffix:@".plist"]) {
			ViLanguage *language = [[ViLanguage alloc] initWithPath:[dir stringByAppendingPathComponent:file]];
			[bundle addLanguage:language];
			[languages setObject:language forKey:[language name]];
		}
	}

	dir = [NSString stringWithFormat:@"%@/Preferences", bundleDirectory];
	for (file in [fm directoryContentsAtPath:dir])
		if ([file hasSuffix:@".plist"])
			[bundle addPreferences:[[NSMutableDictionary alloc] initWithContentsOfFile:[dir stringByAppendingPathComponent:file]]];

	dir = [NSString stringWithFormat:@"%@/Snippets", bundleDirectory];
	for (file in [fm directoryContentsAtPath:dir])
		if ([file hasSuffix:@".tmSnippet"] || [file hasSuffix:@".plist"])
			[bundle addSnippet:[NSDictionary dictionaryWithContentsOfFile:[dir stringByAppendingPathComponent:file]]];

	dir = [NSString stringWithFormat:@"%@/Commands", bundleDirectory];
	for (file in [fm directoryContentsAtPath:dir])
		if ([file hasSuffix:@".tmCommand"] || [file hasSuffix:@".plist"])
			[bundle addCommand:[NSMutableDictionary dictionaryWithContentsOfFile:[dir stringByAppendingPathComponent:file]]];

	[bundles addObject:bundle];

	[[NSNotificationCenter defaultCenter] postNotificationName:ViLanguageStoreBundleLoadedNotification
							    object:self
							  userInfo:[NSDictionary dictionaryWithObject:bundle forKey:@"bundle"]];

	return YES;
}

- (void)addBundlesFromBundleDirectory:(NSString *)aPath
{
	NSArray *subdirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:aPath error:NULL];
	for (NSString *subdir in subdirs)
		[self loadBundleFromDirectory:[NSString stringWithFormat:@"%@/%@", aPath, subdir]];
}

- (void)initLanguages
{
	languages = [[NSMutableDictionary alloc] init];
	bundles = [[NSMutableArray alloc] init];

	[self addBundlesFromBundleDirectory:[ViLanguageStore bundlesDirectory]];
}

+ (ViLanguageStore *)defaultStore
{
	if (defaultStore == nil) {
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

	INFO(@"missing language '%@'", languageName);
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

/*
 * Checks all bundles for the named preferences (yes, this is how TextMate does it).
 */
- (NSDictionary *)preferenceItems:(NSArray *)prefsNames
{
	NSString *cacheKey = [prefsNames componentsJoinedByString:@","];
	NSMutableDictionary *result = [cachedPreferences objectForKey:cacheKey];
	if (result)
		return result;

	result = [[NSMutableDictionary alloc] init];
	[cachedPreferences setObject:result forKey:cacheKey];

	ViBundle *bundle;
	for (bundle in bundles) {
		NSDictionary *p = [bundle preferenceItems:prefsNames];
		if (p)
			[result addEntriesFromDictionary:p];	// XXX: need to do this in two levels? (since items in p are also dictionaries...)
	}

	return result;
}

/*
 * Checks all bundles for the named preference (yes, this is how TextMate does it).
 */
- (NSDictionary *)preferenceItem:(NSString *)prefsName
{
	NSMutableDictionary *result = [cachedPreferences objectForKey:prefsName];
	if (result)
		return result;

	result = [[NSMutableDictionary alloc] init];
	[cachedPreferences setObject:result forKey:prefsName];

	ViBundle *bundle;
	for (bundle in bundles) {
		NSDictionary *p = [bundle preferenceItem:prefsName];
		if (p)
			[result addEntriesFromDictionary:p];
	}

	return result;
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

- (BOOL)isBundleLoaded:(NSString *)name
{
	ViBundle *bundle;
	for (bundle in bundles)
		if ([[bundle path] rangeOfString:name].location != NSNotFound)
			return YES;
	return NO;
}

@end

