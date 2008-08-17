#import "ViLanguageStore.h"


@implementation ViLanguageStore

static ViLanguageStore *defaultStore = nil;

- (void)addLanguage:(ViLanguage *)aLanguage
{
	[languages setObject:aLanguage forKey:[aLanguage name]];
}

- (void)addLanguagesFromBundleDirectory:(NSString *)aPath
{
	NSArray *subdirs = [[NSFileManager defaultManager] directoryContentsAtPath:aPath];
	NSString *subdir;
	for(subdir in subdirs)
	{
		NSString *syntaxPath = [NSString stringWithFormat:@"%@/%@/Syntaxes", aPath, subdir];
		NSArray *syntaxfiles = [[NSFileManager defaultManager] directoryContentsAtPath:syntaxPath];
		NSString *syntaxfile;
		for(syntaxfile in syntaxfiles)
		{
			if([syntaxfile hasSuffix:@".tmLanguage"] || [syntaxfile hasSuffix:@".plist"])
				[self addLanguage:[[ViLanguage alloc] initWithPath:[NSString stringWithFormat:@"%@/%@", syntaxPath, syntaxfile]]];
		}
	}
}

- (void)initLanguages
{
	languages = [[NSMutableDictionary alloc] init];

	BOOL isDirectory = NO;
	
	NSString *bundlesPath = @"/Applications/TextMate.app/Contents/SharedSupport";
	if([[NSFileManager defaultManager] fileExistsAtPath:bundlesPath isDirectory:&isDirectory] && isDirectory)
		[self addLanguagesFromBundleDirectory:bundlesPath];

	bundlesPath = @"/Library/Application Support/TextMate/Bundles";
	if([[NSFileManager defaultManager] fileExistsAtPath:bundlesPath isDirectory:&isDirectory] && isDirectory)
		[self addLanguagesFromBundleDirectory:bundlesPath];

}

+ (ViLanguageStore *)defaultStore
{
	if(defaultStore == nil)
	{
		defaultStore = [[ViLanguageStore alloc] init];
		[defaultStore initLanguages];
	}
	return defaultStore;
}

- (ViLanguage *)languageForFilename:(NSString *)aPath
{
	NSString *extension = [aPath pathExtension];
	ViLanguage *language;
	for(language in [languages allValues])
	{
		NSLog(@"checking language %@...", [language name]);
		NSArray *fileTypes = [language fileTypes];
		NSString *fileType;
		for(fileType in fileTypes)
		{
			if([fileType isEqualToString:extension])
			{
				NSLog(@"Using language %@ for file %@", [language name], aPath);
				return language;
			}
		}
	}
	NSLog(@"No language found for file %@", aPath);
	return nil;
}

@end
