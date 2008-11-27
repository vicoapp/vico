#import "ViLanguage.h"
#import "ViLanguageStore.h"
#import "logging.h"

@implementation ViLanguage

- (ViRegexp *)compileRegexp:(NSString *)pattern
{
	ViRegexp *regexp = nil;
	@try
	{
		regexp = [ViRegexp regularExpressionWithString:pattern];
	}
	@catch (NSException *exception)
	{
		INFO(@"***** FAILED TO COMPILE REGEXP ***** [%@], exception = [%@]", pattern, exception);
		regexp = nil;
	}

	return regexp;
}

- (ViRegexp *)compileRegexp:(NSString *)pattern withBackreferencesToRegexp:(ViRegexpMatch *)beginMatch matchText:(const unichar *)matchText
{
	ViRegexp *regexp = nil;
	@try
	{
		NSMutableString *expandedPattern = [[NSMutableString alloc] initWithString:pattern];
		if (beginMatch)
		{
			INFO(@"*************** expanding pattern with %i captures:", [beginMatch count]);
			INFO(@"** original pattern = [%@]", pattern);
			int i;
			for (i = 1; i <= [beginMatch count]; i++)
			{
				NSRange captureRange = [beginMatch rangeOfSubstringAtIndex:i];
				NSString *capture = [NSString stringWithCharacters:matchText + captureRange.location length:captureRange.length];
				if (capture)
				{
					NSString *backref = [NSString stringWithFormat:@"\\%i", i];
					INFO(@"**** replacing [%@] with [%@]", backref, capture);
					[expandedPattern replaceOccurrencesOfString:backref
									 withString:capture
									    options:0
									      range:NSMakeRange(0, [expandedPattern length])];
				}
			}
			INFO(@"** expanded pattern = [%@]", expandedPattern);
		}

		regexp = [ViRegexp regularExpressionWithString:expandedPattern];
	}
	@catch (NSException *exception)
	{
		INFO(@"***** FAILED TO COMPILE REGEXP ***** [%@], exception = [%@]", pattern, exception);
		regexp = nil;
	}

	return regexp;
}

- (void)compileRegexp:(NSString *)rule inPattern:(NSMutableDictionary *)d
{
	if ([d objectForKey:rule])
	{
		ViRegexp *regexp = [self compileRegexp:[d objectForKey:rule]];
		if (regexp)
			[d setObject:regexp forKey:[NSString stringWithFormat:@"%@Regexp", rule]];
	}
}

- (void)compilePatterns:(NSArray *)patterns
{
	if (patterns == nil)
		return;

	ViRegexp *hasBackRefs = [ViRegexp regularExpressionWithString:@"\\\\([1-9]|k<.*?>)"];

	int n = 0;
	NSMutableDictionary *d;
	for (d in patterns)
	{
		if ([[d objectForKey:@"disabled"] intValue] == 1)
		{
			[d removeAllObjects];
			continue;
		}
		//INFO(@"compiling pattern for scope [%@]", [d objectForKey:@"name"]);
		[self compileRegexp:@"match" inPattern:d];
		[self compileRegexp:@"begin" inPattern:d];
		if ([d objectForKey:@"end"] && ![hasBackRefs matchInString:[d objectForKey:@"end"]])
			[self compileRegexp:@"end" inPattern:d];
		// else we must first substitute back references from the begin match before compiling end regexp
		n++;

		// recursively compile sub-patterns, if any
		NSArray *subPatterns = [d objectForKey:@"patterns"];
		if (subPatterns)
		{
			//INFO(@"compiling sub-patterns for scope [%@]", [d objectForKey:@"name"]);
			[self compilePatterns:subPatterns];
		}
	}
	//INFO(@"compiled %i patterns", n);
}

- (void)compile
{
	DEBUG(@"start compiling language [%@]", [self name]);
	[self compilePatterns:languagePatterns];
	[self compilePatterns:[[language objectForKey:@"repository"] allValues]];
	compiled = YES;
	DEBUG(@"finished compiling language [%@]", [self name]);
}

- (id)initWithPath:(NSString *)aPath
{
	self = [super init];
	if(self == nil)
		return nil;

	compiled = NO;
	language = [NSMutableDictionary dictionaryWithContentsOfFile:aPath];
	languagePatterns = [language objectForKey:@"patterns"];	
	scopeMappingCache = [[NSMutableDictionary alloc] init];

	return self;
}

- (NSArray *)patterns
{
	if (!compiled)
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
	// DEBUG(@"expanding %i patterns from language %@, baseLanguage = %@", [patterns count], [self name], [baseLanguage name]);
	*canCache = YES;

	NSMutableArray *expandedPatterns = [[NSMutableArray alloc] init];
	NSMutableDictionary *pattern;
	for (pattern in patterns)
	{
		// DEBUG(@"  expanding pattern %@", pattern);
		NSString *include = [pattern objectForKey:@"include"];
		if (include == nil)
		{
			// just add this pattern directly
			// set a reference to the language so we can find the correct repository later on
			[pattern setObject:self forKey:@"language"];
			[expandedPatterns addObject:pattern];
			continue;
		}

		// expand this pattern
		if ([include hasPrefix:@"#"])
		{
			// fetch pattern from repository
			NSString *patternName = [include substringFromIndex:1];
			NSMutableDictionary *includePattern = [[language objectForKey:@"repository"] objectForKey:patternName];
			// DEBUG(@"including [%@] with %i patterns from repository of language %@", patternName, [includePattern count], [self name]);
			if (includePattern)
			{
				// DEBUG(@"includePattern = [%@]", includePattern);
				if ([includePattern count] == 1 + ([includePattern objectForKey:@"expandedPatterns"] ? 1 : 0) + ([includePattern objectForKey:@"comment"] ? 1 : 0) && [includePattern objectForKey:@"patterns"])
				{
					// this pattern is just a collection of other patterns
					// no endless loop because expandedPatternsForPattern caches the first recursion
					// DEBUG(@"expanding pattern collection %@", patternName);
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
				INFO(@"***** pattern [%@] NOT FOUND in repository for language [%@] *****", patternName, [self name]);
		}
		else if ([include isEqualToString:@"$base"])
		{
			// no endless loop because expandedPatternsForPattern caches the first recursion
			// DEBUG(@"including %@: baseLanguage.name = %@", include, [baseLanguage name]);
			*canCache = NO;
			[expandedPatterns addObjectsFromArray:[baseLanguage patterns]];
		}
		else if ([include isEqualToString:@"$self"])
		{
			// no endless loop because expandedPatternsForPattern caches the first recursion
			// DEBUG(@"including %@: self.name = %@", include, [self name]);
			[expandedPatterns addObjectsFromArray:[self patterns]];
		}
		else
		{
			// include an external language grammar
			// DEBUG(@"including external language [%@]", include);
			ViLanguage *externalLanguage = [[ViLanguageStore defaultStore] languageWithScope:include];
			if (externalLanguage)
				[expandedPatterns addObjectsFromArray:[externalLanguage patterns]];
			else
				INFO(@"***** language [%@] NOT FOUND *****", include);
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
