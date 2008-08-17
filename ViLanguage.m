#import <OgreKit/OgreKit.h>
#import "ViLanguage.h"

@implementation ViLanguage

- (void)compileRegexp:(NSString *)rule inPattern:(NSMutableDictionary *)d
{
	if([d objectForKey:rule])
	{
		OGRegularExpression *regexp = [OGRegularExpression regularExpressionWithString:[d objectForKey:rule]];
		[d setObject:regexp forKey:[NSString stringWithFormat:@"%@Regexp", rule]];		
	}
}

- (id)initWithBundle:(NSString *)bundleName
{
	self = [super init];
	if(self == nil)
		return nil;

	NSString *path = [[NSBundle mainBundle] pathForResource:bundleName ofType:@"tmLanguage"];
	if(![[NSFileManager defaultManager] fileExistsAtPath:path])
		path = [[NSBundle mainBundle] pathForResource:bundleName ofType:@"plist"];
	if(path == nil)
		return nil;
	language = [NSMutableDictionary dictionaryWithContentsOfFile:path];
	NSLog(@"language = [%@]", language);

	languagePatterns = [language objectForKey:@"patterns"];
	NSLog(@"%s got %i patterns", _cmd, [languagePatterns count]);
	NSMutableDictionary *d;
	for(d in languagePatterns)
	{
		if([d objectForKey:@"name"] == nil)
			/* we don't support includes yet */
			continue;

		NSLog(@"%s got pattern for scope [%@]", _cmd, [d objectForKey:@"name"]);
		[self compileRegexp:@"match" inPattern:d];
		[self compileRegexp:@"begin" inPattern:d];
		[self compileRegexp:@"end" inPattern:d];
	}
	return self;
}

- (NSArray *)patterns;
{
	return languagePatterns;
}

@end
