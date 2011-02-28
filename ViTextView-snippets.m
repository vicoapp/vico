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

- (ViSnippet *)insertSnippet:(NSString *)snippetString
                  fromBundle:(ViBundle *)bundle
                     inRange:(NSRange)aRange
{
	// prepend leading whitespace to all newlines in the snippet string
	NSString *leadingWhiteSpace = [[self textStorage] leadingWhitespaceForLineAtLocation:aRange.location];
	NSString *indentedNewline = [@"\n" stringByAppendingString:leadingWhiteSpace];
	NSString *indentedSnippetString = [snippetString stringByReplacingOccurrencesOfString:@"\n" withString:indentedNewline];

	// FIXME: replace tabs with correct shiftwidth/tabstop settings

	NSMutableDictionary *env = [[NSMutableDictionary alloc] init];
	[env addEntriesFromDictionary:[[NSProcessInfo processInfo] environment]];
	[ViBundle setupEnvironment:env forTextView:self];

	/* Additional bundle specific variables. */
	[env setObject:[bundle path] forKey:@"TM_BUNDLE_PATH"];
	NSString *bundleSupportPath = [bundle supportPath];
	[env setObject:bundleSupportPath forKey:@"TM_BUNDLE_SUPPORT"];

	[self beginUndoGroup];

	[self deleteRange:aRange];

	NSError *error = nil;
	ViSnippet *snippet = [[ViSnippet alloc] initWithString:indentedSnippetString
	                                            atLocation:aRange.location
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

	snippetMatchRange.location = NSNotFound;

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

- (void)performBundleSnippet:(ViBundleSnippet *)bundleSnippet
{
	[self insertSnippet:[bundleSnippet content]
	         fromBundle:[bundleSnippet bundle]
	            inRange:snippetMatchRange];
}

@end
