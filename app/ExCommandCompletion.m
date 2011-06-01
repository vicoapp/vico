#import "ExCommandCompletion.h"
#import "ExCommand.h"
#include "logging.h"

@implementation ExCommandCompletion

- (id<ViDeferred>)completionsForString:(NSString *)word
			       options:(NSString *)options
			    onResponse:(void (^)(NSArray *, NSError *))responseCallback
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
	ViRegexp *rx = [[ViRegexp alloc] initWithString:pattern
						options:rx_options];

	NSMutableArray *commands = [NSMutableArray array];
	int i;
	for (i = 0; ex_commands[i].name; i++) {
		NSString *name = ex_commands[i].name;
		ViRegexpMatch *m = nil;
		if (pattern == nil || (m = [rx matchInString:name]) != nil) {
			ViCompletion *c;
			if (fuzzySearch)
				c = [ViCompletion completionWithContent:name fuzzyMatch:m];
			else
				c = [ViCompletion completionWithContent:name prefixLength:[word length]];
			[commands addObject:c];
		}
	}

	responseCallback(commands, nil);

	return nil;
}

@end
