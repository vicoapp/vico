#import "ViSyntaxCompletion.h"
#import "ViBundleStore.h"
#include "logging.h"

@implementation ViSyntaxCompletion

- (id<ViDeferred>)completionsForString:(NSString *)word
			       options:(NSString *)options
			    onResponse:(void (^)(NSArray *, NSError *))responseCallback
{
	BOOL fuzzySearch = ([options rangeOfString:@"f"].location != NSNotFound);
	BOOL fuzzyTrigger = ([options rangeOfString:@"F"].location != NSNotFound);

	DEBUG(@"completing syntax [%@] w/options %@", word, options);

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

	NSMutableArray *syntaxes = [NSMutableArray array];
	NSArray *languages = [[ViBundleStore defaultStore] languages];
	for (ViLanguage *lang in languages) {
		NSString *name = lang.name;
		ViRegexpMatch *m = nil;
		if (pattern == nil || (m = [rx matchInString:name]) != nil) {
			ViCompletion *c;
			if (fuzzySearch)
				c = [ViCompletion completionWithContent:name fuzzyMatch:m];
			else
				c = [ViCompletion completionWithContent:name prefixLength:[word length]];
			[syntaxes addObject:c];
		}
	}

	responseCallback(syntaxes, nil);

	return nil;
}

@end
