#import "ViLanguage.h"
#import "ViLanguageStore.h"

@implementation ViLanguage

- (OGRegularExpression *)compileRegexp:(NSString *)pattern withBackreferencesToRegexp:(OGRegularExpressionMatch *)beginMatch
{
	OGRegularExpression *regexp = nil;
	//NSLog(@" compiling regexp [%@]", pattern);
	@try
	{
		NSMutableString *expandedPattern = [[NSMutableString alloc] initWithString:pattern];
		if(beginMatch)
		{
			NSLog(@"*************** expanding pattern with %i captures:", [beginMatch count]);
			NSLog(@"** original pattern = [%@]", pattern);
			int i;
			for(i = 1; i < [beginMatch count]; i++)
			{
				NSString *backref = [NSString stringWithFormat:@"\\%i", i];
				[expandedPattern replaceOccurrencesOfString:backref
								 withString:[beginMatch substringAtIndex:i]
								    options:0
								      range:NSMakeRange(1, [expandedPattern length])];
			}
			NSLog(@"** expanded pattern = [%@]", expandedPattern);
		}

		regexp = [OGRegularExpression regularExpressionWithString:expandedPattern options:OgreCaptureGroupOption];
	}
	@catch(NSException *exception)
	{
		NSLog(@"***** FAILED TO COMPILE REGEXP ***** [%@]", pattern);
		regexp = nil;
	}

	return regexp;
}

- (void)compileRegexp:(NSString *)rule inPattern:(NSMutableDictionary *)d
{
	if([d objectForKey:rule])
	{
		OGRegularExpression *regexp = [self compileRegexp:[d objectForKey:rule] withBackreferencesToRegexp:nil];
		if(regexp)
			[d setObject:regexp forKey:[NSString stringWithFormat:@"%@Regexp", rule]];
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
		//NSLog(@"compiling pattern for scope [%@]", [d objectForKey:@"name"]);
		[self compileRegexp:@"match" inPattern:d];
		[self compileRegexp:@"begin" inPattern:d];
		[self compileRegexp:@"end" inPattern:d];
		n++;

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

	//NSLog(@"Initializing language from file %@", aPath);
	compiled = NO;
	language = [NSMutableDictionary dictionaryWithContentsOfFile:aPath];
	//NSLog(@"language = [%@]", language);
	languagePatterns = [language objectForKey:@"patterns"];	
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

- (NSArray *)patterns
{
	if(!compiled)
		[self compile];
	return [self expandedPatternsForPattern:language];
}

- (NSArray *)fileTypes
{
	return [language objectForKey:@"fileTypes"];
}

- (NSString *)name
{
	return [language objectForKey:@"scopeName"];
}

- (NSArray *)expandPatterns:(NSArray *)patterns
{
	NSMutableArray *expandedPatterns = [[NSMutableArray alloc] init];
	NSDictionary *pattern;
	for(pattern in patterns)
	{
		NSString *include = [pattern objectForKey:@"include"];
		if(include == nil)
		{
			// just add this pattern directly
			[expandedPatterns addObject:pattern];
			continue;
		}

		// expand this pattern
		if([include hasPrefix:@"#"])
		{
			// fetch pattern from repository
			NSString *patternName = [include substringFromIndex:1];
			NSLog(@"including [%@] from repository", patternName);
			// FIXME: use correct repository if referenced from an external language
			NSMutableDictionary *includePattern = [[language objectForKey:@"repository"] objectForKey:patternName];
			if(includePattern)
			{
				if([includePattern count] == 1 && [includePattern objectForKey:@"patterns"])
				{
					// no endless loop because expandedPatternsForPattern caches the first recursion
					[expandedPatterns addObjectsFromArray:[self expandedPatternsForPattern:includePattern]];
				}
				else
					[expandedPatterns addObject:includePattern];
			}
			else
				NSLog(@"pattern [%@] NOT FOUND in repository", patternName);
		}
		else if([include isEqualToString:@"$base"] || [include isEqualToString:@"$self"])
		{
			// FIXME: $base vs. $self !?
			// no endless loop because expandedPatternsForPattern caches the first recursion
			[expandedPatterns addObjectsFromArray:[self patterns]];
		}
		else
		{
			// include an external language grammar
			NSLog(@"including external language [%@]", include);
			ViLanguage *externalLanguage = [[ViLanguageStore defaultStore] languageWithScope:include];
			if(externalLanguage)
				[expandedPatterns addObjectsFromArray:[externalLanguage patterns]];
			else
				NSLog(@"language [%@] NOT FOUND", include);
		}
	}
	return expandedPatterns;
}

- (NSArray *)expandedPatternsForPattern:(NSMutableDictionary *)pattern
{
	NSArray *expandedPatterns = [pattern objectForKey:@"expandedPatterns"];
	if(expandedPatterns == nil)
	{
		expandedPatterns = [self expandPatterns:[pattern objectForKey:@"patterns"]];
		if(expandedPatterns)
		{
			// cache it
			[pattern setObject:expandedPatterns forKey:@"expandedPatterns"];
		}
	}
	return expandedPatterns;
}

@end
