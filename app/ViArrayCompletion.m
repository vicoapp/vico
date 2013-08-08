#import "ViArrayCompletion.h"

@implementation ViArrayCompletion

@synthesize completions = _completions;

+ (ViArrayCompletion *)arrayCompletionWithArray:(NSArray *)completions
{
	return [[self alloc] initWithArray:completions];
}

- (ViArrayCompletion *)initWithArray:(NSArray *)completions
{
	if (self = [super init]) {
		self.completions = completions;
	}

	return self;
}

- (NSArray *)completionsForString:(NSString *)word
						  options:(NSString *)options
							error:(NSError **)outError
{
	BOOL fuzzySearch = ([options rangeOfString:@"f"].location != NSNotFound);
	BOOL fuzzyTrigger = ([options rangeOfString:@"F"].location != NSNotFound);

	NSMutableString *pattern = [NSMutableString string];
	if ([word length] == 0)
		pattern = nil;
	else if (fuzzyTrigger)
		[ViCompletionController appendFilter:word toPattern:pattern fuzzyClass:@"."];
	else
		pattern = [NSString stringWithFormat:@"^%@.*", word, nil];

	ViRegexp *regexp = [ViRegexp regexpWithString:pattern options:0];
	ViRegexp *softRegexp = [ViRegexp regexpWithString:pattern options:ONIG_OPTION_IGNORECASE];

	NSMutableArray *matchingCompletions = [NSMutableArray array];
	NSMutableArray *softMatchingCompletions = [NSMutableArray array];
	for (NSString *completion in self.completions) {
		ViRegexpMatch *match = nil, *softMatch = nil;
		if (pattern != nil &&
			(((match = [regexp matchInString:completion]) != nil) ||
			 ((softMatch = [softRegexp matchInString:completion]) != nil))) {
			ViRegexpMatch *matchToUse = match ? match : softMatch;

			ViCompletion *fullCompletion;
			if (fuzzySearch)
				fullCompletion = [ViCompletion completionWithContent:completion fuzzyMatch:matchToUse];
			else
				fullCompletion = [ViCompletion completionWithContent:completion];

			if (match)
				[matchingCompletions addObject:fullCompletion];
			else
				[softMatchingCompletions addObject:fullCompletion];
		}
	}

	[matchingCompletions addObjectsFromArray:softMatchingCompletions];
	NSLog(@"Filtered by %@ to %@", pattern, matchingCompletions);

	return matchingCompletions;
}

- (void)dealloc
{
	self.completions = nil;

	[super dealloc];
}

@end
