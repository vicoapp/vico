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

#import "ViWordCompletion.h"
#import "ViWindowController.h"
#import "ViError.h"
#include "logging.h"

@implementation ViWordCompletion

- (NSArray *)completionsForString:(NSString *)word
			  options:(NSString *)options
			    error:(NSError **)outError
{
	ViTextView *text = [[[ViWindowController currentWindowController] currentDocumentView] textView];
	if (text == nil) {
		if (outError)
			*outError = [ViError message:@"Word completion only defined for text views"];
		return nil;
	}

	NSUInteger wordlen = [word length];

	ViTextStorage *textStorage = [text viTextStorage];
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

	NSInteger rx_options = [ViRegexp defaultOptionsForString:pattern] | ONIG_OPTION_NOTBOL | ONIG_OPTION_NOTEOL;
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

	return [[uniq allObjects] sortedArrayUsingComparator:sortByLocation];
}

@end

