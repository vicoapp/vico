#import "ViBundleStore.h"
#import "ViBundle.h"
#import "ViAppController.h"
#import "ViBundleItem.h"
#import "NSString-scopeSelector.h"
#import "logging.h"

@implementation ViBundleStore

static ViBundleStore *defaultStore = nil;
static NSString *bundlesDirectory = nil;

+ (NSString *)bundlesDirectory
{
	if (bundlesDirectory == nil)
		bundlesDirectory = [[NSString stringWithFormat:@"%@/Bundles",
		    [ViAppController supportDirectory]] stringByExpandingTildeInPath];
	return bundlesDirectory;
}

- (id)init
{
	self = [super init];
	if (self) {
		languages = [NSMutableDictionary dictionary];
		cachedPreferences = [NSMutableDictionary dictionary];
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
			ViLanguage *language = [[ViLanguage alloc] initWithPath:[dir stringByAppendingPathComponent:file]
								      forBundle:bundle];
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

	[[NSNotificationCenter defaultCenter] postNotificationName:ViBundleStoreBundleLoadedNotification
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

	[self addBundlesFromBundleDirectory:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Resources/Bundles"]];
	[self addBundlesFromBundleDirectory:[ViBundleStore bundlesDirectory]];
}

+ (ViBundleStore *)defaultStore
{
	if (defaultStore == nil) {
		defaultStore = [[ViBundleStore alloc] init];
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

		ViRegexp *rx = [[ViRegexp alloc] initWithString:firstLineMatch];
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
			NSUInteger path_len = [aPath length];
			NSUInteger ftype_len = [fileType length];

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

- (ViBundle *)bundleWithName:(NSString *)name
{
	for (ViBundle *b in bundles)
		if ([[b name] isEqualToString:name])
			return b;
	return nil;
}

- (ViBundle *)bundleWithUUID:(NSString *)uuid
{
	for (ViBundle *b in bundles)
		if ([[b uuid] isEqualToString:uuid])
			return b;
	return nil;
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

- (NSArray *)itemsWithTabTrigger:(NSString *)prefix
                  matchingScopes:(NSArray *)scopes
                          inMode:(ViMode)mode
                   matchedLength:(NSUInteger *)lengthPtr
{
	NSMutableArray *matches = nil;
	u_int64_t highest_rank = 0ULL;
	NSUInteger longestMatch = 0ULL;

	for (ViBundle *bundle in bundles)
		for (ViBundleItem *item in [bundle items])
			if ([item tabTrigger] &&
			    [prefix hasSuffix:[item tabTrigger]] &&
			    ([item mode] == ViAnyMode || [item mode] == mode)) {
				/*
				 * Try to match as much of the tab trigger as possible.
				 * Favor longer matching tab trigger words.
				 */
				NSUInteger triggerLength = [[item tabTrigger] length];
				if (triggerLength > longestMatch) {
					[matches removeAllObjects];
					longestMatch = triggerLength;
				} else if (triggerLength < longestMatch)
					continue;

				NSString *scope = [item scope];
				u_int64_t rank;
				if (scope == nil)
					rank = 1ULL;
				else
					rank = [scope matchesScopes:scopes];

				if (rank > 0) {
					if (rank > highest_rank) {
						matches = [NSMutableArray arrayWithObject:item];
						highest_rank = rank;
					} else if (rank == highest_rank)
						[matches addObject:item];
				}
			}

	if (lengthPtr)
		*lengthPtr = longestMatch;

	return matches;
}

- (NSArray *)itemsWithKeyCode:(NSInteger)keyCode
               matchingScopes:(NSArray *)scopes
                       inMode:(ViMode)mode
{
	NSMutableArray *matches = nil;
	u_int64_t highest_rank = 0ULL;

	for (ViBundle *bundle in bundles)
		for (ViBundleItem *item in [bundle items])
			if ([item keyCode] == keyCode &&
			    ([item mode] == ViAnyMode || [item mode] == mode)) {
				NSString *scope = [item scope];
				u_int64_t rank;
				if (scope == nil)
					rank = 1ULL;
				else
					rank = [scope matchesScopes:scopes];

				if (rank > 0) {
					if (rank > highest_rank) {
						matches = [NSMutableArray arrayWithObject:item];
						highest_rank = rank;
					} else if (rank == highest_rank)
						[matches addObject:item];
				}
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

