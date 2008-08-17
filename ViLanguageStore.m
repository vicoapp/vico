#import "ViLanguageStore.h"


@implementation ViLanguageStore

static ViLanguageStore *defaultStore = nil;

- (void)initLanguages
{
	languages = [[NSMutableArray alloc] init];
	[languages addObject:[[ViLanguage alloc] initWithBundle:@"HTML"]];
	[languages addObject:[[ViLanguage alloc] initWithBundle:@"Objective-C"]];
	[languages addObject:[[ViLanguage alloc] initWithBundle:@"C"]];
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
	for(language in languages)
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
