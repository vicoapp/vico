#import <OgreKit/OgreKit.h>
#import "ViLanguage.h"

@implementation ViLanguage

- (void)compileRegexp:(NSString *)rule inPattern:(NSMutableDictionary *)d
{
	if([d objectForKey:rule])
	{
		//NSLog(@"  compiling regexp %@ [%@]", rule, [d objectForKey:rule]);
		@try
		{
			OGRegularExpression *regexp = [OGRegularExpression regularExpressionWithString:[d objectForKey:rule]];
			[d setObject:regexp forKey:[NSString stringWithFormat:@"%@Regexp", rule]];
		}
		@catch(NSException *exception)
		{
			NSLog(@"***** FAILED TO COMPILE REGEXP ***** [%@]", [d objectForKey:rule]);			
		}
	}
}

- (void)compile
{
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
	compiled = YES;
}

- (id)initWithPath:(NSString *)aPath
{
	self = [super init];
	if(self == nil)
		return nil;

	NSLog(@"Initializing language from file %@", aPath);
	compiled = NO;
	language = [NSMutableDictionary dictionaryWithContentsOfFile:aPath];
	//NSLog(@"language = [%@]", language);
	languagePatterns = [language objectForKey:@"patterns"];	
	//NSLog(@"%s got %i patterns", _cmd, [languagePatterns count]);
	scopeMappingCache = [[NSMutableDictionary alloc] init];

	return self;
}

- (id)initWithBundle:(NSString *)bundleName
{
	NSLog(@"Initializing language from bundle %@", bundleName);

	NSString *path = [[NSBundle mainBundle] pathForResource:bundleName ofType:@"tmLanguage"];
	if(![[NSFileManager defaultManager] fileExistsAtPath:path])
	{
		NSLog(@"%@.tmLanguage not found, trying %@.plist", bundleName, bundleName);
		path = [[NSBundle mainBundle] pathForResource:bundleName ofType:@"plist"];
	}
	if(path == nil)
	{
		NSLog(@"%@.plist not found, giving up", bundleName);
		return nil;
	}

	return [self initWithPath:path];
}

- (NSArray *)patterns;
{
	if(!compiled)
		[self compile];
	return languagePatterns;
}

- (NSArray *)fileTypes
{
	return [language objectForKey:@"fileTypes"];
}

- (NSString *)name
{
	return [language objectForKey:@"name"];
}

- (NSDictionary *)patternForScope:(NSString *)aScopeSelector
{
	// look in cache first
	NSMutableDictionary *d = [scopeMappingCache objectForKey:aScopeSelector];
	if(d)
		return d;

	// walk through all patterns and match the scope selector
	for(d in languagePatterns)
	{
		if([[d objectForKey:@"name"] isEqualToString:aScopeSelector])
		{
			// add to cache
			[scopeMappingCache setObject:d forKey:aScopeSelector];
			return d;
		}
	}
	return nil;
}

@end
