#import "ViWordCompletion.h"
#import "ViWindowController.h"
#include "logging.h"

@implementation ViWordCompletion

- (id<ViDeferred>)completionsForString:(NSString *)word
			       options:(NSString *)options
			    onResponse:(void (^)(NSArray *, NSError *))responseCallback
{
	ViTextView *text = (ViTextView *)[[[ViWindowController currentWindowController] currentView] innerView];
	if (![text isKindOfClass:[ViTextView class]]) {
		responseCallback(nil, nil);
		return nil;
	}

	NSUInteger wordlen = [word length];

	ViTextStorage *textStorage = [text textStorage];
	NSUInteger currentLocation = [text caret] - wordlen;

	BOOL fuzzySearch = ([options rangeOfString:@"f"].location != NSNotFound);
	BOOL fuzzyTrigger = ([options rangeOfString:@"F"].location != NSNotFound);
	NSString *pattern;
	if (wordlen == 0) {
		pattern = @"\\b\\w{3,}";
	} else if (fuzzyTrigger) { /* Fuzzy completion trigger. */
		pattern = [NSMutableString string];
		[(NSMutableString *)pattern appendString:@"\\b\\w*"];
		[ViCompletionController appendFilter:word
					   toPattern:(NSMutableString *)pattern
					  fuzzyClass:@"\\w"];
		[(NSMutableString *)pattern appendString:@"\\w*"];
	} else {
		pattern = [NSString stringWithFormat:@"\\b(%@)\\w*", word];
	}

	DEBUG(@"searching for %@", pattern);

	unsigned rx_options = ONIG_OPTION_NOTBOL | ONIG_OPTION_NOTEOL | ONIG_OPTION_IGNORECASE;
	ViRegexp *rx;
	rx = [ViRegexp regexpWithString:pattern
				options:rx_options];
	NSArray *foundMatches = [rx allMatchesInString:[textStorage string]
					       options:rx_options];

	NSMutableSet *uniqWords = [NSMutableSet set];
	NSMutableSet *uniq = [NSMutableSet set];
	for (ViRegexpMatch *m in foundMatches) {
		NSRange r = [m rangeOfMatchedString];
		if (r.location == NSNotFound || r.location == currentLocation)
			/* Don't include the word we're about to complete. */
			continue;
		NSString *content = [[textStorage string] substringWithRange:r];
		if ([uniqWords containsObject:content])
			continue;
		ViCompletion *c;
		if (fuzzySearch)
			c = [ViCompletion completionWithContent:content fuzzyMatch:m];
		else {
			c = [ViCompletion completionWithContent:content];
			c.prefixLength = wordlen;
		}
		c.location = r.location;
		[uniq addObject:c];
		[uniqWords addObject:content];
	}

	BOOL sortDescending = ([options rangeOfString:@"d"].location != NSNotFound);
	NSComparator sortByLocation = ^(id a, id b) {
		ViCompletion *ca = a, *cb = b;
		NSUInteger al = ca.location;
		NSUInteger bl = cb.location;
		if (al > bl) {
			if (bl < currentLocation && al > currentLocation)
				return (NSComparisonResult)(sortDescending ? NSOrderedDescending : NSOrderedAscending); // a < b
			return (NSComparisonResult)(sortDescending ? NSOrderedAscending : NSOrderedDescending); // a > b
		} else if (al < bl) {
			if (al < currentLocation && bl > currentLocation)
				return (NSComparisonResult)(sortDescending ? NSOrderedAscending : NSOrderedDescending); // a > b
			return (NSComparisonResult)(sortDescending ? NSOrderedDescending : NSOrderedAscending); // a < b
		}
		return (NSComparisonResult)NSOrderedSame;
	};
	NSArray *completions = [[uniq allObjects] sortedArrayUsingComparator:sortByLocation];

	responseCallback(completions, nil);
	return nil;
}

@end

