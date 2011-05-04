#import "ViBufferCompletion.h"
#include "logging.h"

@implementation ViBufferCompletion

- (id)initWithWindowController:(ViWindowController *)aWindowController
{
	if ((self = [super init]) != nil) {
		windowController = aWindowController;
	}
	return self;
}

- (id<ViDeferred>)completionsForString:(NSString *)word
			       options:(NSString *)options
			    onResponse:(void (^)(NSArray *, NSError *))responseCallback
{
	BOOL fuzzySearch = ([options rangeOfString:@"f"].location != NSNotFound);
	BOOL fuzzyTrigger = ([options rangeOfString:@"F"].location != NSNotFound);

	DEBUG(@"completing buffer [%@] w/options %@", word, options);

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

	NSMutableArray *buffers = [NSMutableArray array];
	for (ViDocument *doc in [windowController documents]) {
		NSString *fn = [[doc fileURL] absoluteString];
		if (fn == nil)
			continue;
		ViRegexpMatch *m = nil;
		if (pattern == nil || (m = [rx matchInString:fn]) != nil) {
			ViCompletion *c;
			if (fuzzySearch)
				c = [ViCompletion completionWithContent:fn fuzzyMatch:m];
			else
				c = [ViCompletion completionWithContent:fn prefixLength:[word length]];
			[buffers addObject:c];
		}
	}

	responseCallback(buffers, nil);

	return nil;
}

@end
