#import "ViTextView.h"
#import "ViSnippet.h"

@implementation ViTextView (snippets)

- (void)cancelSnippet:(ViSnippet *)snippet
{
	// remove the temporary attribute, effectively cancelling the snippet
	INFO(@"cancel snippet in range %@", NSStringFromRange(snippet.range));
	[self performSelector:@selector(removeTemporaryAttribute:) withObject:[NSDictionary dictionaryWithObjectsAndKeys:
		ViSnippetAttributeName, @"attributeName",
		[NSValue valueWithRange:snippet.range], @"range",
		nil] afterDelay:0];
	
}

- (void)gotoTabstop:(int)num inSnippet:(ViSnippet *)snippet
{
	// ViSnippetPlaceholder *placeholder = [snippet firstPlaceholderWithIndex:num];
	ViSnippetPlaceholder *placeholder = nil;
	if ([[snippet tabstops] count] >= num)
		placeholder = [[[snippet tabstops] objectAtIndex:num - 1] objectAtIndex:0];

	if (placeholder == nil)
	{
		placeholder = snippet.lastPlaceholder;
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

	// mark the snippet range with a temporary attribute
	[self performSelector:@selector(addTemporaryAttribute:) withObject:[NSDictionary dictionaryWithObjectsAndKeys:
		ViSnippetAttributeName, @"attributeName",
		snippet, @"value",
		[NSValue valueWithRange:NSMakeRange(aLocation, [[snippet string] length])], @"range",
		nil] afterDelay:0];

        // FIXME: sort tabstops, go to tabstop 1 first, then 2, 3, 4, ... and last to 0
        [self gotoTabstop:1 inSnippet:snippet];
        return snippet;
}

- (ViSnippet *)snippetAtLocation:(NSUInteger)aLocation
{
	ViSnippet *snippet = [[self layoutManager] temporaryAttribute:ViSnippetAttributeName
						      atCharacterIndex:aLocation
						        effectiveRange:NULL];
	return snippet;
}

- (NSRange)trackSnippet:(ViSnippet *)snippetToTrack forward:(BOOL)forward fromLocation:(NSUInteger)aLocation
{
	NSRange trackedRange = NSMakeRange(aLocation, 0);
	NSUInteger i = aLocation;
	for (;;)
	{
		if (forward && i >= [storage length])
			break;
		else if (!forward && i == 0)
			break;
	
		NSRange range = NSMakeRange(i, 0);
		ViSnippet *snippet = [[self layoutManager] temporaryAttribute:ViSnippetAttributeName
							     atCharacterIndex:i
							       effectiveRange:&range];
		if (snippet == nil)
			break;

		if (snippet == snippetToTrack)
			trackedRange = NSUnionRange(trackedRange, range);
		else
			break;

		if (forward)
			i += range.length;
		else
			i -= range.length;
	}

	return trackedRange;
}

- (void)handleSnippetTab:(ViSnippet *)snippet atLocation:(NSUInteger)aLocation
{
	INFO(@"current tab index is %i", snippet.currentTab);

#if 0
	/* Find the total range of the snippet. */
	/* FIXME: must mark newly inserted characters with the surrounding snippet. */
	NSRange rb = [self trackSnippet:state forward:NO  fromLocation:[self caret]];
	NSRange rf = [self trackSnippet:state forward:YES fromLocation:[self caret]];
	NSRange range = NSUnionRange(rb, rf);
#endif

	[self gotoTabstop:snippet.currentTab + 1 inSnippet:snippet];
}

@end

