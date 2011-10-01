#import "ExCommandCompletion.h"
#import "ExMap.h"
#include "logging.h"

@implementation ExCommandCompletion

- (NSArray *)completionsForString:(NSString *)word
			  options:(NSString *)options
			    error:(NSError **)outError
{
	BOOL fuzzySearch = ([options rangeOfString:@"f"].location != NSNotFound);
	BOOL fuzzyTrigger = ([options rangeOfString:@"F"].location != NSNotFound);

	DEBUG(@"completing command [%@] w/options %@", word, options);

	NSMutableString *pattern = [NSMutableString string];
	if ([word length] == 0)
		pattern = nil;
	else if (fuzzyTrigger)
		[ViCompletionController appendFilter:word toPattern:pattern fuzzyClass:@"."];
	else
		pattern = [NSString stringWithFormat:@"^%@.*", word];

	unsigned rx_options = ONIG_OPTION_IGNORECASE;
	ViRegexp *rx = [ViRegexp regexpWithString:pattern options:rx_options];

	NSMutableArray *commands = [NSMutableArray array];
	for (ExMapping *mapping in [ExMap defaultMap].mappings) {
		NSString *name = mapping.name;
		ViRegexpMatch *m = nil;
		if (pattern == nil || (m = [rx matchInString:name]) != nil) {
			ViCompletion *c;
			if (fuzzySearch)
				c = [ViCompletion completionWithContent:name fuzzyMatch:m];
			else
				c = [ViCompletion completionWithContent:name];
			[commands addObject:c];
		}
	}

	return commands;
}

@end

