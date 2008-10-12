#import "ViLanguage.h"
#import "ViLanguageStore.h"
#import "logging.h"

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
			// NSLog(@"*************** expanding pattern with %i captures:", [beginMatch count]);
			// NSLog(@"** original pattern = [%@]", pattern);
			int i;
			for(i = 1; i <= [beginMatch count]; i++)
			{
				NSString *backref = [NSString stringWithFormat:@"\\%i", i];
				if([beginMatch substringAtIndex:i])
				{
					// NSLog(@"**** replacing [%@] with [%@]", backref, [beginMatch substringAtIndex:i]);
					[expandedPattern replaceOccurrencesOfString:backref
									 withString:[beginMatch substringAtIndex:i]
									    options:0
									      range:NSMakeRange(0, [expandedPattern length])];
				}
			}
			// NSLog(@"** expanded pattern = [%@]", expandedPattern);
		}

		regexp = [OGRegularExpression regularExpressionWithString:expandedPattern options:OgreCaptureGroupOption];
	}
	@catch(NSException *exception)
	{
		NSLog(@"***** FAILED TO COMPILE REGEXP ***** [%@], exception = [%@]", pattern, exception);
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

	OGRegularExpression *hasBackRefs = [OGRegularExpression regularExpressionWithString:@"\\\\([1-9]|k<.*?>)"];

	int n = 0;
	NSMutableDictionary *d;
	for(d in patterns)
	{
		if([[d objectForKey:@"disabled"] intValue] == 1)
		{
			[d removeAllObjects];
			continue;
		}
		//NSLog(@"compiling pattern for scope [%@]", [d objectForKey:@"name"]);
		[self compileRegexp:@"match" inPattern:d];
		[self compileRegexp:@"begin" inPattern:d];
		if([d objectForKey:@"end"] && ![hasBackRefs matchInString:[d objectForKey:@"end"]])
			[self compileRegexp:@"end" inPattern:d];
		// else we must first substitute back references from the begin match before compiling end regexp
		n++;

		// recursively compile sub-patterns, if any
		NSArray *subPatterns = [d objectForKey:@"patterns"];
		if(subPatterns)
		{
			//NSLog(@"compiling sub-patterns for scope [%@]", [d objectForKey:@"name"]);
			[self compilePatterns:subPatterns];
		}
	}
	//NSLog(@"compiled %i patterns", n);
}

- (void)compile
{
	NSLog(@"start compiling language [%@]", [self name]);
	[self compilePatterns:languagePatterns];
	[self compilePatterns:[[language objectForKey:@"repository"] allValues]];
	compiled = YES;
	NSLog(@"finished compiling language [%@]", [self name]);
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
	// NSLog(@"Initializing language from bundle %@", bundleName);

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

- (NSString *)firstLineMatch
{
	return [language objectForKey:@"firstLineMatch"];
}

- (NSString *)name
{
	return [language objectForKey:@"scopeName"];
}

- (NSString *)displayName
{
	return [language objectForKey:@"name"];
}

- (NSArray *)expandPatterns:(NSArray *)patterns baseLanguage:(ViLanguage *)baseLanguage canCache:(BOOL *)canCache
{
	DEBUG(@"expanding %i patterns from language %@, baseLanguage = %@", [patterns count], [self name], [baseLanguage name]);
	*canCache = YES;

	NSMutableArray *expandedPatterns = [[NSMutableArray alloc] init];
	NSMutableDictionary *pattern;
	for(pattern in patterns)
	{
		NSString *include = [pattern objectForKey:@"include"];
		if(include == nil)
		{
			// just add this pattern directly
			// set a reference to the language so we can find the correct repository later on
			[pattern setObject:self forKey:@"language"];
			[expandedPatterns addObject:pattern];
			continue;
		}

		// expand this pattern
		if([include hasPrefix:@"#"])
		{
			// fetch pattern from repository
			NSString *patternName = [include substringFromIndex:1];
			DEBUG(@"including [%@] from repository of language %@", patternName, [self name]);
			NSMutableDictionary *includePattern = [[language objectForKey:@"repository"] objectForKey:patternName];
			if(includePattern)
			{
				if([includePattern count] == 1 + ([includePattern objectForKey:@"expandedPatterns"] ? 1 : 0) && [includePattern objectForKey:@"patterns"])
				{
					// this pattern is just a collection of other patterns
					// no endless loop because expandedPatternsForPattern caches the first recursion
					DEBUG(@"expanding pattern collection %@", patternName);
					[expandedPatterns addObjectsFromArray:[self expandedPatternsForPattern:includePattern baseLanguage:baseLanguage]];
				}
				else
				{
					// this pattern is a real pattern (possibly with sub-patterns)
					[includePattern setObject:self forKey:@"language"];
					[expandedPatterns addObject:includePattern];
				}
			}
			else
				NSLog(@"***** pattern [%@] NOT FOUND in repository for language [%@] *****", patternName, [self name]);
		}
		else if([include isEqualToString:@"$base"])
		{
			// no endless loop because expandedPatternsForPattern caches the first recursion
			DEBUG(@"including %@: baseLanguage.name = %@", include, [baseLanguage name]);
			*canCache = NO;
			[expandedPatterns addObjectsFromArray:[baseLanguage patterns]];
		}
		else if([include isEqualToString:@"$self"])
		{
			// no endless loop because expandedPatternsForPattern caches the first recursion
			DEBUG(@"including %@: self.name = %@", include, [self name]);
			[expandedPatterns addObjectsFromArray:[self patterns]];
		}
		else
		{
			// include an external language grammar
			DEBUG(@"including external language [%@]", include);
			ViLanguage *externalLanguage = [[ViLanguageStore defaultStore] languageWithScope:include];
			if (externalLanguage)
				[expandedPatterns addObjectsFromArray:[externalLanguage patterns]];
			else
				NSLog(@"***** language [%@] NOT FOUND *****", include);
		}
	}
	return expandedPatterns;
}

- (NSArray *)expandedPatternsForPattern:(NSMutableDictionary *)pattern baseLanguage:(ViLanguage *)baseLanguage
{
	NSArray *expandedPatterns = [pattern objectForKey:@"expandedPatterns"];
	if(expandedPatterns == nil)
	{
		ViLanguage *lang = [pattern objectForKey:@"language"];
		if(lang == nil)
			lang = self;

		BOOL canCache = YES;
		expandedPatterns = [lang expandPatterns:[pattern objectForKey:@"patterns"] baseLanguage:baseLanguage canCache:&canCache];
		if(expandedPatterns && canCache)
		{
			// cache it
			[pattern setObject:expandedPatterns forKey:@"expandedPatterns"];
		}
	}
	return expandedPatterns;
}

- (NSArray *)expandedPatternsForPattern:(NSMutableDictionary *)pattern
{
	return [self expandedPatternsForPattern:pattern baseLanguage:self];
}

@end
