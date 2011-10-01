#import "ViBufferCompletion.h"
#include "logging.h"

@implementation ViBufferCompletion

- (NSArray *)completionsForString:(NSString *)word
			  options:(NSString *)options
			    error:(NSError **)outError
{
	BOOL fuzzySearch = ([options rangeOfString:@"f"].location != NSNotFound);
	BOOL fuzzyTrigger = ([options rangeOfString:@"F"].location != NSNotFound);

	DEBUG(@"completing buffer [%@] w/options %@", word, options);

	NSMutableString *pattern = [NSMutableString string];
	NSUInteger wordlen = [word length];
	if (wordlen == 0)
		pattern = nil;
	else if (fuzzyTrigger)
		[ViCompletionController appendFilter:word toPattern:pattern fuzzyClass:@"."];
	else
		pattern = [NSString stringWithFormat:@"^%@.*", word];

	unsigned rx_options = ONIG_OPTION_IGNORECASE;
	ViRegexp *rx = [ViRegexp regexpWithString:pattern options:rx_options];

	NSMutableArray *buffers = [NSMutableArray array];
	for (ViDocument *doc in [[ViWindowController currentWindowController] documents]) {
		NSString *fn = [[doc fileURL] absoluteString];
		if (fn == nil)
			continue;
		ViRegexpMatch *m = nil;
		if (pattern == nil || (m = [rx matchInString:fn]) != nil) {
			ViCompletion *c;
			if (fuzzySearch)
				c = [ViCompletion completionWithContent:fn fuzzyMatch:m];
			else {
				c = [ViCompletion completionWithContent:fn];
				c.prefixLength = wordlen;
			}
			[buffers addObject:c];
		}
	}

	return buffers;
}

@end
