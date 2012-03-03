#import "ViLanguage.h"
#import "ViBundleStore.h"
#import "logging.h"

@implementation ViLanguage

@synthesize bundle = _bundle;
@synthesize scope = _scope;
@synthesize uuid = _uuid;

- (id)initWithPath:(NSString *)aPath forBundle:(ViBundle *)aBundle
{
	if ((self = [super init]) != nil) {
		_bundle = aBundle;	// XXX: not retained!
		_compiled = NO;
		_language = [[NSMutableDictionary dictionaryWithContentsOfFile:aPath] mutableCopy];
		if (![_language isKindOfClass:[NSDictionary class]]) {
			INFO(@"%@: failed to load plist", aPath);
			[self release];
			return nil;
		}

		_uuid = [[_language objectForKey:@"uuid"] retain];
		if (_uuid == nil) {
			INFO(@"missing uuid in language %@", aPath);
			[self release];
			return nil;
		}

		_languagePatterns = [[_language objectForKey:@"patterns"] retain];
		if (![_languagePatterns isKindOfClass:[NSArray class]]) {
			INFO(@"%@: failed to load plist", aPath);
			[self release];
			return nil;
		}

		if ([[self name] length] > 0)
			_scope = [[ViScope alloc] initWithScopes:[NSArray arrayWithObject:[self name]]
							   range:NSMakeRange(0, 0)];
	}

	DEBUG_INIT();
	return self;
}

- (void)dealloc
{
	DEBUG_DEALLOC();
	[_language release];
	[_languagePatterns release];
	[_scope release];
	[super dealloc];
}

- (ViRegexp *)compileRegexp:(NSString *)pattern
 withBackreferencesToRegexp:(ViRegexpMatch *)beginMatch
                  matchText:(const unichar *)matchText
{
	if (beginMatch == nil)
		return [ViRegexp regexpWithString:pattern];

	NSMutableString *expandedPattern = [NSMutableString stringWithString:pattern];
	DEBUG(@"*************** expanding pattern with %i captures:", [beginMatch count]);
	DEBUG(@"** original pattern = [%@]", pattern);
	for (NSUInteger i = 1; i <= [beginMatch count]; i++) {
		NSRange captureRange = [beginMatch rangeOfSubstringAtIndex:i];
		captureRange.location -= [beginMatch startLocation];
		NSString *capture = [ViRegexp escape:[NSString stringWithCharacters:matchText + captureRange.location
									     length:captureRange.length]];
		if (capture) {
			NSString *backref = [NSString stringWithFormat:@"\\%lu", i];
			DEBUG(@"**** replacing [%@] with [%@]", backref, capture);
			[expandedPattern replaceOccurrencesOfString:backref
							 withString:capture
							    options:0
							      range:NSMakeRange(0, [expandedPattern length])];
		}
	}
	DEBUG(@"** expanded pattern = [%@]", expandedPattern);

	return [ViRegexp regexpWithString:expandedPattern];
}

- (void)compileRegexp:(NSString *)rule inPattern:(NSMutableDictionary *)d
{
	NSString *rulePattern = [d objectForKey:rule];
	if ([rulePattern isKindOfClass:[NSString class]]) {
		ViRegexp *regexp = [ViRegexp regexpWithString:rulePattern];
		if (regexp)
			[d setObject:regexp forKey:[NSString stringWithFormat:@"%@Regexp", rule]];
	}
}

- (void)compilePatterns:(NSArray *)patterns
{
	if (patterns == nil)
		return;

	ViRegexp *hasBackRefs = [ViRegexp regexpWithString:@"\\\\([1-9]|k<.*?>)"];

	for (NSMutableDictionary *d in patterns) {
		if ([[d objectForKey:@"disabled"] intValue] == 1) {
			[d removeAllObjects];
			continue;
		}

		[self compileRegexp:@"match" inPattern:d];
		[self compileRegexp:@"begin" inPattern:d];
		if ([d objectForKey:@"end"] && ![hasBackRefs matchInString:[d objectForKey:@"end"]])
			[self compileRegexp:@"end" inPattern:d];
		// else we must first substitute back references from the begin match before compiling end regexp

		// recursively compile sub-patterns, if any
		NSArray *subPatterns = [d objectForKey:@"patterns"];
		if ([subPatterns isKindOfClass:[NSArray class]]) {
			//INFO(@"compiling sub-patterns for scope [%@]", [d objectForKey:@"name"]);
			[self compilePatterns:subPatterns];
		}
	}
}

- (void)compile
{
	DEBUG(@"start compiling language [%@]", [self name]);
	[self compilePatterns:_languagePatterns];
	NSDictionary *repository = [_language objectForKey:@"repository"];
	if ([repository isKindOfClass:[NSDictionary class]])
		[self compilePatterns:[repository allValues]];
	_compiled = YES;
	DEBUG(@"finished compiling language [%@]", [self name]);
}

- (NSArray *)patterns
{
	if (!_compiled)
		[self compile];
	return [self expandedPatternsForPattern:_language];
}

- (NSArray *)fileTypes
{
	return [_language objectForKey:@"fileTypes"];
}

- (NSString *)firstLineMatch
{
	return [_language objectForKey:@"firstLineMatch"];
}

- (NSString *)name
{
	return [_language objectForKey:@"scopeName"];
}

- (NSString *)displayName
{
	return [_language objectForKey:@"name"];
}

- (NSString *)injectionSelector
{
	return [_language objectForKey:@"injectionSelector"];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViLanguage %p: %@ (%@)>", self, [self name], [self displayName]];
}

- (NSArray *)expandPatterns:(NSArray *)patterns baseLanguage:(ViLanguage *)baseLanguage
{
	// DEBUG(@"expanding %i patterns from language %@, baseLanguage = %@", [patterns count], [self name], [baseLanguage name]);

	NSMutableArray *expandedPatterns = [NSMutableArray array];
	for (NSMutableDictionary *pattern in patterns) {
		// DEBUG(@"  expanding pattern %@", pattern);
		NSString *include = [pattern objectForKey:@"include"];
		if (![include isKindOfClass:[NSString class]]) {
			// just add this pattern directly
			// set a reference to the language so we can find the correct repository later on
			[pattern setObject:self forKey:@"language"];
			[expandedPatterns addObject:pattern];
			continue;
		}

		// expand this pattern
		if ([include hasPrefix:@"#"]) {
			// fetch pattern from repository
			NSString *patternName = [include substringFromIndex:1];
			NSMutableDictionary *includePattern = [[_language objectForKey:@"repository"] objectForKey:patternName];
			if ([includePattern isKindOfClass:[NSDictionary class]]) {
				// DEBUG(@"includePattern = [%@]", includePattern);
				int n = 1;
				for (NSString *key in [includePattern allKeys])
					if ([key hasPrefix:@"expandedPatterns."] || [key isEqualToString:@"comment"])
						++n;

				if ([includePattern count] == n && [includePattern objectForKey:@"patterns"]) {
					// this pattern is just a collection of other patterns
					// no endless loop because expandedPatternsForPattern caches the first recursion
					// DEBUG(@"expanding pattern collection %@", patternName);
					[expandedPatterns addObjectsFromArray:[self expandedPatternsForPattern:includePattern
												  baseLanguage:baseLanguage]];
				} else {
					// this pattern is a real pattern (possibly with sub-patterns)
					[includePattern setObject:self forKey:@"language"]; // XXX: circular reference
					[expandedPatterns addObject:includePattern];
				}
			} else
				INFO(@"***** pattern [%@] NOT FOUND in repository for language [%@] *****", patternName, [self name]);
		}
		else if ([include isEqualToString:@"$base"])
		{
			[expandedPatterns addObjectsFromArray:[baseLanguage patterns]];
		}
		else if ([include isEqualToString:@"$self"])
		{
			[expandedPatterns addObjectsFromArray:[self patterns]];
		}
		else
		{
			// include an external language grammar
			ViLanguage *externalLanguage = [[ViBundleStore defaultStore] languageWithScope:include];
			if (externalLanguage)
				[expandedPatterns addObjectsFromArray:[externalLanguage patterns]];
			else
				INFO(@"***** language [%@] NOT FOUND *****", include);
		}
	}
	return expandedPatterns;
}

- (NSArray *)expandedPatternsForPattern:(NSMutableDictionary *)pattern
                           baseLanguage:(ViLanguage*)baseLanguage
{
	NSString *cacheKey = [NSString stringWithFormat:@"expandedPatterns.%@", [baseLanguage name]];
	NSArray *expandedPatterns = [pattern objectForKey:cacheKey];
	if (expandedPatterns == nil) {
		ViLanguage *lang = [pattern objectForKey:@"language"];
		if (lang == nil)
			lang = self;

		expandedPatterns = [lang expandPatterns:[pattern objectForKey:@"patterns"]
					   baseLanguage:baseLanguage];
		if (expandedPatterns) 
			[pattern setObject:expandedPatterns forKey:cacheKey];
	}
	return expandedPatterns;
}

- (NSArray *)expandedPatternsForPattern:(NSMutableDictionary *)pattern
{
	return [self expandedPatternsForPattern:pattern baseLanguage:self];
}

@end
