/*
 * Copyright (c) 2008-2012 Martin Hedenfalk <martin@vicoapp.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ViTextView.h"
#import "ViSnippet.h"
#import "ViDocument.h"
#import "ViBundleSnippet.h"

@implementation ViTextView (snippets)

- (void)cancelSnippet
{
	ViSnippet *snippet = [[document.snippet retain] autorelease];
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

	NSMutableDictionary *env = [NSMutableDictionary dictionary];
	[ViBundle setupEnvironment:env forTextView:self window:[self window] bundle:bundle];

	[self endUndoGroup];
	[self beginUndoGroup];
	[[self textStorage] beginEditing];
	[self deleteRange:aRange];

	snippetMatchRange.location = NSNotFound;

	NSError *error = nil;
	ViSnippet *snippet = [[[ViSnippet alloc] initWithString:expandedSnippetString
						     atLocation:aRange.location
						       delegate:self
						    environment:env
							  error:&error] autorelease];
	[[self textStorage] endEditing];
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
