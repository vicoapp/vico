#import "ViTextView.h"
#import "ViSnippet.h"
#import "ViDocument.h"
#import "ViBundleSnippet.h"

@implementation ViTextView (snippets)

- (void)cancelSnippet:(ViSnippet *)snippet
{
	DEBUG(@"cancel snippet in range %@", NSStringFromRange(snippet.range));
	[self delegate].snippet = nil;
	[[self layoutManager] invalidateDisplayForCharacterRange:snippet.range];
	[self endUndoGroup];
}

- (ViSnippet *)insertSnippet:(NSString *)snippetString atLocation:(NSUInteger)aLocation
{
	// prepend leading whitespace to all newlines in the snippet string
	NSString *leadingWhiteSpace = [[self textStorage] leadingWhitespaceForLineAtLocation:aLocation];
	NSString *indentedNewline = [@"\n" stringByAppendingString:leadingWhiteSpace];
	NSString *indentedSnippetString = [snippetString stringByReplacingOccurrencesOfString:@"\n" withString:indentedNewline];

	// FIXME: replace tabs with correct shiftwidth/tabstop settings

	NSMutableDictionary *env = [[NSMutableDictionary alloc] init];
	[ViBundle setupEnvironment:env forTextView:self];

	[self beginUndoGroup];

	NSError *error = nil;
	ViSnippet *snippet = [[ViSnippet alloc] initWithString:indentedSnippetString
	                                            atLocation:aLocation
	                                              delegate:self
	                                           environment:env
	                                                 error:&error];
	if (snippet == nil) {
		INFO(@"error is %@", [error localizedDescription]);
		[[self delegate] message:[error localizedDescription]];
		return nil;
	}

	[self delegate].snippet = snippet;
	final_location = snippet.caret;
	[self setCaret:snippet.caret];
	[self setInsertMode:nil];
	[self resetSelection];

	return snippet;
}

- (void)deselectSnippet
{
	ViSnippet *snippet = [self delegate].snippet;
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

	[self endUndoGroup];
	[self beginUndoGroup];

	if (snippetMatchRange.location != NSNotFound) {
		[self deleteRange:snippetMatchRange];
		[self setCaret:snippetMatchRange.location];
		snippetMatchRange.location = NSNotFound;
	}

	[self insertSnippet:[bundleSnippet content] atLocation:[self caret]];
}

@end
