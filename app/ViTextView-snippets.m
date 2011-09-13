#import "ViTextView.h"
#import "ViSnippet.h"
#import "ViDocument.h"
#import "ViBundleSnippet.h"

@implementation ViTextView (snippets)

- (void)cancelSnippet
{
	ViSnippet *snippet = document.snippet;
	if (snippet) {
		DEBUG(@"cancel snippet in range %@", NSStringFromRange(snippet.range));
		document.snippet = nil;
		[[self layoutManager] invalidateDisplayForCharacterRange:snippet.range];
		[self endUndoGroup];
	}
}

- (ViSnippet *)insertSnippet:(NSString *)snippetString
		   andIndent:(BOOL)indent
                  fromBundle:(ViBundle *)bundle
                     inRange:(NSRange)aRange
{
	DEBUG(@"insert snippet [%@] at %@", snippetString, NSStringFromRange(aRange));
	NSString *expandedSnippetString = snippetString;
	if (indent) {
		// prepend leading whitespace to all newlines in the snippet string
		NSString *leadingWhiteSpace = [[self textStorage] leadingWhitespaceForLineAtLocation:aRange.location];
		NSString *indentedNewline = [@"\n" stringByAppendingString:leadingWhiteSpace];
		NSString *indentedSnippetString = [snippetString stringByReplacingOccurrencesOfString:@"\n"
											   withString:indentedNewline
											      options:0
												range:NSMakeRange(0, IMAX(0, [snippetString length] - 1))];

		expandedSnippetString = indentedSnippetString;
		if ([[self preference:@"expandtab" atLocation:aRange.location] integerValue] == NSOnState) {
			NSInteger shiftWidth = [[self preference:@"shiftwidth" atLocation:aRange.location] integerValue];
			NSString *tabString = [@"" stringByPaddingToLength:shiftWidth withString:@" " startingAtIndex:0];
			expandedSnippetString = [indentedSnippetString stringByReplacingOccurrencesOfString:@"\t" withString:tabString];
		}
		DEBUG(@"expanded snippet to [%@]", expandedSnippetString);
	}

	NSMutableDictionary *env = [[NSMutableDictionary alloc] init];
	[ViBundle setupEnvironment:env forTextView:self window:[self window] bundle:bundle];

	[self endUndoGroup];
	[self beginUndoGroup];
	[self deleteRange:aRange];

	snippetMatchRange.location = NSNotFound;

	NSError *error = nil;
	ViSnippet *snippet = [[ViSnippet alloc] initWithString:expandedSnippetString
	                                            atLocation:aRange.location
	                                              delegate:self
	                                           environment:env
	                                                 error:&error];
	if (snippet == nil) {
		MESSAGE(@"%@", [error localizedDescription]);
		final_location = aRange.location;
		[self setCaret:aRange.location];
		return nil;
	}

	document.snippet = snippet;
	final_location = snippet.caret;
	[self setCaret:snippet.caret];

	/*
	 * If we have an active tab stop (apart from $0), force insert mode.
	 */
	if (snippet.selectedRange.length > 0)
		[self setInsertMode:nil];
	else if (mode == ViVisualMode)
		[self setNormalMode];

	[self resetSelection];
	[self updateStatus];

	return snippet;
}

- (ViSnippet *)insertSnippet:(NSString *)snippetString
                     inRange:(NSRange)aRange
{
	return [self insertSnippet:snippetString
			 andIndent:YES
	                fromBundle:nil
	                   inRange:aRange];
}

- (ViSnippet *)insertSnippet:(NSString *)snippetString
                  atLocation:(NSUInteger)aLocation
{
	return [self insertSnippet:snippetString
			 andIndent:YES
	                fromBundle:nil
	                   inRange:NSMakeRange(aLocation, 0)];
}

- (ViSnippet *)insertSnippet:(NSString *)snippetString
{
	return [self insertSnippet:snippetString
			 andIndent:YES
	                fromBundle:nil
	                   inRange:NSMakeRange([self caret], 0)];
}

- (void)deselectSnippet
{
	ViSnippet *snippet = document.snippet;
	if (snippet) {
		NSRange sel = snippet.selectedRange;
		if (sel.location != NSNotFound) {
			[[self layoutManager] invalidateDisplayForCharacterRange:sel];
			[snippet deselect];
		}
	}
}

- (void)performBundleSnippet:(ViBundleSnippet *)bundleSnippet
{
	NSRange r;

	if (snippetMatchRange.location == NSNotFound) {
		r = [self selectedRange];
		if (r.length == 0)
			r = NSMakeRange([self caret], 0);
	} else
		r = snippetMatchRange;

	[self insertSnippet:[bundleSnippet content]
		  andIndent:YES
	         fromBundle:[bundleSnippet bundle]
	            inRange:r];
}

@end
