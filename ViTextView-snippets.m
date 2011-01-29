#import "ViTextView.h"
#import "ViSnippet.h"
#import "ViDocument.h"
#import "ViBundleSnippet.h"

@implementation ViTextView (snippets)

- (void)cancelSnippet:(ViSnippet *)snippet
{
	// remove the temporary attribute, effectively cancelling the snippet
	DEBUG(@"cancel snippet in range %@", NSStringFromRange(snippet.range));
	[[self delegate] setActiveSnippet:nil];
	[[self layoutManager] invalidateDisplayForCharacterRange:snippet.range];
}

- (void)gotoTabstop:(int)num inSnippet:(ViSnippet *)snippet
{
	ViSnippetPlaceholder *placeholder = nil;
	if (num < [[snippet tabstops] count])
		placeholder = [[[snippet tabstops] objectAtIndex:num] objectAtIndex:0];

	if (placeholder == nil) {
		placeholder = snippet.lastPlaceholder;
		DEBUG(@"last placeholder in snippet %@", snippet);
	}

	if (placeholder) {
		DEBUG(@"placing cursor at tabstop %i, range %@", placeholder.tabStop, NSStringFromRange(placeholder.range));
		final_location = placeholder.range.location;
		snippet.currentTab = placeholder.tabStop;
		snippet.currentPlaceholder = placeholder;
		placeholder.selected = YES;
	} else {
		[self cancelSnippet:snippet];
		final_location = NSMaxRange(snippet.range);
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
	if ([[snippet tabstops] count] > 1)
		[self gotoTabstop:1 inSnippet:snippet];
	else {
		[self gotoTabstop:0 inSnippet:snippet];
		return nil;
	}

	return snippet;
}

- (void)handleSnippetTab:(ViSnippet *)snippet atLocation:(NSUInteger)aLocation
{
	DEBUG(@"current tab index is %i", snippet.currentTab);

	[self gotoTabstop:snippet.currentTab + 1 inSnippet:snippet];
}

/* Called by the ViTextView when inserting a string inside the snippet.
 * Extends the snippet temporary attribute over the inserted text.
 * If inside a place holder range, updates the range. Also handles mirror
 * place holders.
 */
- (BOOL)updateSnippet:(ViSnippet *)snippet replaceRange:(NSRange)replaceRange withString:(NSString *)string
{
	DEBUG(@"found snippet %@ while updating %@ with %@", snippet, NSStringFromRange(replaceRange), string);
#ifndef NO_DEBUG
	NSRange currentRange = snippet.currentPlaceholder.range;
	DEBUG(@"current range = %@, current value = %@", NSStringFromRange(currentRange), snippet.currentPlaceholder.value);
#endif

	snippet.currentPlaceholder.selected = NO;

	// verify we're inserting inside the current placeholder, or appending to it
	if (![snippet.currentPlaceholder activeInRange:replaceRange]) {
		DEBUG(@"outside current placeholder, cancelling snippet %@", snippet);
		return NO;
	}

	NSInteger delta = [string length] - replaceRange.length;
	[snippet updateLength:delta fromLocation:replaceRange.location];

	NSRange newRange = snippet.currentPlaceholder.range;
	newRange.length += delta;
	NSString *value = [[[self textStorage] string] substringWithRange:newRange];
	[snippet.currentPlaceholder updateValue:value];

	/*
	 * If this placeholder has mirrors, update them too.
	 */
	int ctab = snippet.currentPlaceholder.tabStop;
	NSArray *mirrors = [snippet.tabstops objectAtIndex:ctab];
	int i;
	for (i = 1; i < [mirrors count]; i++) {
		ViSnippetPlaceholder *mirror = [mirrors objectAtIndex:i];
		NSRange oldRange = mirror.range;
		delta = [mirror updateValue:value];
		[snippet updateLength:delta fromLocation:mirror.range.location];

		[[self delegate] setActiveSnippet:nil];	// XXX: isn't this an ugly hack!?
		[self replaceRange:oldRange withString:mirror.value];
		[[self delegate] setActiveSnippet:snippet];
	}

	DEBUG(@"tabstops after push = [%@]", snippet.tabstops);

	return YES;
}

- (void)performBundleSnippet:(id)sender
{
	ViBundleSnippet *bundleSnippet = sender;
	if ([sender respondsToSelector:@selector(representedObject)])
		bundleSnippet = [sender representedObject];

	[self beginUndoGroup];
	ViSnippet *snippet = [self insertSnippet:[bundleSnippet content] atLocation:[self caret]];
	[[self delegate] setActiveSnippet:snippet];

	if (snippet && snippet.currentPlaceholder.selected) {
		[self setSelectedRange:snippet.currentPlaceholder.range];
		if ([snippet done])
			[self cancelSnippet:snippet];
	}
}

@end

