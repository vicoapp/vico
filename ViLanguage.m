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

- (void)compilePatterns:(NSArray *)patterns
{
	if(patterns == nil)
		return;

	int n = 0;
	NSMutableDictionary *d;
	for(d in patterns)
	{
		if([d objectForKey:@"name"])
		{
			NSLog(@"compiling pattern for scope [%@]", [d objectForKey:@"name"]);
			[self compileRegexp:@"match" inPattern:d];
			[self compileRegexp:@"begin" inPattern:d];
			[self compileRegexp:@"end" inPattern:d];
			n++;
		}
		// recursively compile sub-patterns, if any
		NSArray *subPatterns = [d objectForKey:@"patterns"];
		if(subPatterns)
		{
			NSLog(@"compiling sub-patterns");
			[self compilePatterns:subPatterns];
		}
	}
	NSLog(@"compiled %i patterns", n);
}

- (void)compile
{
	NSLog(@"== compiling base language patterns");
	[self compilePatterns:languagePatterns];
	NSLog(@"== compiling repository patterns");
	[self compilePatterns:[[language objectForKey:@"repository"] allValues]];
	NSLog(@"== done compiling language");
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

// FIXME: unused, obsolete(?)
- (NSArray *)patternsForScope:(NSString *)scope
{
	if(!compiled)
		[self compile];
	if(scope == nil)
	{
		return [self expandedPatternsForPattern:language];
	}

	/* find the pattern for the scope */
	NSDictionary *pattern = [self patternForScope:scope];
	if(pattern)
	{
		return [pattern objectForKey:@"patterns"];
	}

	return nil;
}

- (NSArray *)fileTypes
{
	return [language objectForKey:@"fileTypes"];
}

- (NSString *)name
{
	return [language objectForKey:@"name"];
}

- (NSMutableDictionary *)patternForScope:(NSString *)aScopeSelector
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

- (NSArray *)expandedPatterns:(NSArray *)patterns
{
	NSMutableArray *expandedPatterns = [[NSMutableArray alloc] init];
	NSDictionary *pattern;
	for(pattern in patterns)
	{
		NSString *include = [pattern objectForKey:@"include"];
		if(include)
		{
			if([include hasPrefix:@"#"])
			{
				/* fetch pattern from repository */
				NSLog(@"including [%@] from repository", [include substringFromIndex:1]);
				NSDictionary *includePattern = [[language objectForKey:@"repository"] objectForKey:[include substringFromIndex:1]];
				if(includePattern)
				{
					if([includePattern count] == 1 && [includePattern objectForKey:@"patterns"])
					{
						// FIXME: possible endless recursion!
						[expandedPatterns addObjectsFromArray:[self expandedPatterns:[includePattern objectForKey:@"patterns"]]];
					}
					else
						[expandedPatterns addObject:includePattern];
				}
				else
					NSLog(@"pattern [%@] NOT FOUND in repository", [include substringFromIndex:1]);
			}
		}
		else
		{
			[expandedPatterns addObject:pattern];
		}
	}
	return expandedPatterns;
}

- (NSArray *)expandedPatternsForPattern:(NSMutableDictionary *)pattern
{
	NSArray *expandedPatterns = [pattern objectForKey:@"expandedPatterns"];
	if(expandedPatterns == nil)
	{
		expandedPatterns = [self expandedPatterns:[pattern objectForKey:@"patterns"]];
		if(expandedPatterns)
		{
			// cache it
			[pattern setObject:expandedPatterns forKey:@"expandedPatterns"];
		}
	}
	return expandedPatterns;
}

@end
