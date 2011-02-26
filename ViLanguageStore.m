#import "ViLanguageStore.h"
#import "ViBundle.h"
#import "ViAppController.h"
#import "logging.h"

@implementation ViLanguageStore

static ViLanguageStore *defaultStore = nil;
static NSString *bundlesDirectory = nil;

+ (NSString *)bundlesDirectory
{
	if (bundlesDirectory == nil)
		bundlesDirectory = [[NSString stringWithFormat:@"%@/Bundles", [ViAppController supportDirectory]] stringByExpandingTildeInPath];
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
	for (file in [fm contentsOfDirectoryAtPath:dir error:NULL]) {
		if ([file hasSuffix:@".tmLanguage"] || [file hasSuffix:@".plist"]) {
			ViLanguage *language = [[ViLanguage alloc] initWithPath:[dir stringByAppendingPathComponent:file] forBundle:bundle];
			[bundle addLanguage:language];
			[languages setObject:language forKey:[language name]];
		}
	}

	dir = [NSString stringWithFormat:@"%@/Preferences", bundleDirectory];
	for (file in [fm contentsOfDirectoryAtPath:dir error:NULL])
		if ([file hasSuffix:@".plist"] || [file hasSuffix:@".tmPreferences"])
			[bundle addPreferences:[[NSMutableDictionary alloc] initWithContentsOfFile:[dir stringByAppendingPathComponent:file]]];

	dir = [NSString stringWithFormat:@"%@/Snippets", bundleDirectory];
	for (file in [fm contentsOfDirectoryAtPath:dir error:NULL])
		if ([file hasSuffix:@".tmSnippet"] || [file hasSuffix:@".plist"])
			[bundle addSnippet:[NSDictionary dictionaryWithContentsOfFile:[dir stringByAppendingPathComponent:file]]];

	dir = [NSString stringWithFormat:@"%@/Commands", bundleDirectory];
	for (file in [fm contentsOfDirectoryAtPath:dir error:NULL])
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

- (ViLanguage *)languageForFirstLine:(NSString *)firstLine
{
	ViLanguage *language;
	for (language in [self languages]) {
		NSString *firstLineMatch = [language firstLineMatch];
		if (firstLineMatch == nil)
			continue;

		ViRegexp *rx = [ViRegexp regularExpressionWithString:firstLineMatch];
		if ([rx matchInString:firstLine]) {
			DEBUG(@"Using language %@ for first line [%@]", [language name], firstLine);
			DEBUG(@"Using bundle %@", [[language bundle] name]);
			return language;
		}
	}

	DEBUG(@"No language matching first line [%@]", firstLine);
	return nil;
}

- (ViLanguage *)languageForFilename:(NSString *)aPath
{
	NSCharacterSet *pathSeparators = [NSCharacterSet characterSetWithCharactersInString:@"./"];
	ViLanguage *language;

	for (language in [self languages]) {
		NSArray *fileTypes = [language fileTypes];
		NSString *fileType;

		for (fileType in fileTypes) {
			unsigned path_len = [aPath length];
			unsigned ftype_len = [fileType length];

			if ([aPath hasSuffix:fileType] &&
			    (path_len == ftype_len ||
			     [pathSeparators characterIsMember:[aPath characterAtIndex:path_len - ftype_len - 1]])) {
				DEBUG(@"Using language %@ for file %@", [language name], aPath);
				DEBUG(@"Using bundle %@", [[language bundle] name]);
				return language;
			}
		}
	}

	DEBUG(@"No language found for file %@", aPath);
	return nil;
}

- (ViLanguage *)defaultLanguage
{
	return [self languageWithScope:@"text.plain"];
}

- (ViLanguage *)languageWithScope:(NSString *)scopeName
{
	return [languages objectForKey:scopeName];
}

- (NSArray *)languages
{
	return [languages allValues];
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

- (NSArray *)snippetsWithTabTrigger:(NSString *)name matchingScopes:(NSArray *)scopes inMode:(ViMode)mode
{
	NSMutableArray *matches = [[NSMutableArray alloc] init];
	for (ViBundle *bundle in bundles) {
		NSArray *m = [bundle snippetsWithTabTrigger:name matchingScopes:scopes inMode:mode];
		[matches addObjectsFromArray:m];
	}

	return matches;
}

- (NSArray *)commandsWithKey:(unichar)keycode andFlags:(unsigned int)flags matchingScopes:(NSArray *)scopes inMode:(ViMode)mode
{
	NSMutableArray *matches = [[NSMutableArray alloc] init];
	for (ViBundle *bundle in bundles) {
		NSArray *m = [bundle commandsWithKey:keycode andFlags:flags matchingScopes:scopes inMode:mode];
		[matches addObjectsFromArray:m];
	}

	return matches;
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

