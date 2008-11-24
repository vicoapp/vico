#import "ViTextView.h"
#import "ViSnippet.h"

@implementation ViTextView (snippets)

- (void)cancelSnippet:(ViSnippet *)snippet
{
	// remove the temporary attribute, effectively cancelling the snippet
	INFO(@"cancel snippet in range %@", NSStringFromRange(snippet.range));
	activeSnippet = nil;
}

- (void)gotoTabstop:(int)num inSnippet:(ViSnippet *)snippet
{
	ViSnippetPlaceholder *placeholder = nil;
	if ([[snippet tabstops] count] >= num)
		placeholder = [[[snippet tabstops] objectAtIndex:num - 1] objectAtIndex:0];

	if (placeholder == nil)
	{
		placeholder = snippet.lastPlaceholder;
		INFO(@"last placeholder, cancelling snippet");
		[self cancelSnippet:snippet];
	}

	if (placeholder)
	{
		INFO(@"placing cursor at tabstop %i, range %@", placeholder.tabStop, NSStringFromRange(placeholder.range));
		NSRange range = placeholder.range;
		[self setSelectedRange:range];
		snippet.currentTab = placeholder.tabStop;
		snippet.currentPlaceholder = placeholder;
	}
}

- (ViSnippet *)insertSnippet:(NSString *)snippetString atLocation:(NSUInteger)aLocation
{
	// prepend leading whitespace to all newlines in the snippet string
	NSString *leadingWhiteSpace = [self leadingWhitespaceForLineAtLocation:aLocation];
	NSString *indentedNewline = [@"\n" stringByAppendingString:leadingWhiteSpace];
	NSString *indentedSnippetString = [snippetString stringByReplacingOccurrencesOfString:@"\n" withString:indentedNewline];
	
	// FIXME: replace tabs with correct shiftwidth/tabstop settings

	ViSnippet *snippet = [[ViSnippet alloc] initWithString:indentedSnippetString atLocation:aLocation];
	[self insertString:[snippet string] atLocation:aLocation];

        // FIXME: sort tabstops, go to tabstop 1 first, then 2, 3, 4, ... and last to 0
        [self gotoTabstop:1 inSnippet:snippet];
        return snippet;
}

- (void)handleSnippetTab:(ViSnippet *)snippet atLocation:(NSUInteger)aLocation
{
	INFO(@"current tab index is %i", snippet.currentTab);

	[self gotoTabstop:snippet.currentTab + 1 inSnippet:snippet];
}

@end

