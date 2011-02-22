#import "ViTextView.h"
#import "ViSnippet.h"
#import "ViDocument.h"
#import "ViBundleSnippet.h"

@implementation ViTextView (snippets)

- (void)cancelSnippet:(ViSnippet *)snippet
{
	DEBUG(@"cancel snippet in range %@", NSStringFromRange(snippet.range));
	[[self delegate] setActiveSnippet:nil];
	[[self layoutManager] invalidateDisplayForCharacterRange:snippet.range];
	[self endUndoGroup];
}

- (ViSnippet *)insertSnippet:(NSString *)snippetString atLocation:(NSUInteger)aLocation
{
	// prepend leading whitespace to all newlines in the snippet string
	NSString *leadingWhiteSpace = [self leadingWhitespaceForLineAtLocation:aLocation];
	NSString *indentedNewline = [@"\n" stringByAppendingString:leadingWhiteSpace];
	NSString *indentedSnippetString = [snippetString stringByReplacingOccurrencesOfString:@"\n" withString:indentedNewline];

	// FIXME: replace tabs with correct shiftwidth/tabstop settings

	NSMutableDictionary *env = [[NSMutableDictionary alloc] init];
	[ViBundle setupEnvironment:env forTextView:self];
	NSError *error = nil;
	ViSnippet *snippet = [[ViSnippet alloc] initWithString:indentedSnippetString
	                                            atLocation:aLocation
	                                           environment:env
	                                                 error:&error];
	if (snippet == nil) {
		INFO(@"error is %@", [error localizedDescription]);
		[[self delegate] message:[error localizedDescription]];
		return nil;
	}
	[self insertString:[snippet string] atLocation:aLocation];

	final_location = [snippet caret];

	return snippet;
}

- (void)deselectSnippet
{
	ViSnippet *snippet = [[self delegate] activeSnippet];
	if (snippet) {
		NSRange sel = snippet.selectedRange;
		if (sel.location != NSNotFound) {
			[[self layoutManager] invalidateDisplayForCharacterRange:sel];
			[snippet deselect];
		}
	}
}

- (void)performBundleSnippet:(id)sender
{
	ViBundleSnippet *bundleSnippet = sender;
	if ([sender respondsToSelector:@selector(representedObject)])
		bundleSnippet = [sender representedObject];

	[self beginUndoGroup];

	if (snippetMatchRange.location != NSNotFound) {
		[self deleteRange:snippetMatchRange];
		[self setCaret:snippetMatchRange.location];
		snippetMatchRange.location = NSNotFound;
	}

	ViSnippet *snippet = [self insertSnippet:[bundleSnippet content] atLocation:[self caret]];
	if (snippet == nil)
		return;

	DEBUG(@"activate snippet %@", snippet);
	[[self delegate] setActiveSnippet:snippet];
	[self setCaret:snippet.caret];
	[self setInsertMode:nil];
	[self resetSelection];
}

@end

