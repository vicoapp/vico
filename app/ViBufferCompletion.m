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

#import "ViBufferCompletion.h"
#include "logging.h"

@implementation ViBufferCompletion

- (NSArray *)completionsForString:(NSString *)word
			  options:(NSString *)options
			    error:(NSError **)outError
{
	BOOL fuzzySearch = ([options rangeOfString:@"f"].location != NSNotFound);
	BOOL fuzzyTrigger = ([options rangeOfString:@"F"].location != NSNotFound);

	DEBUG(@"completing buffer [%@] w/options %@", word, options);

	NSMutableString *pattern = [NSMutableString string];
	NSUInteger wordlen = [word length];
	if (wordlen == 0)
		pattern = nil;
	else if (fuzzyTrigger)
		[ViCompletionController appendFilter:word toPattern:pattern fuzzyClass:@"."];
	else
		pattern = [NSMutableString stringWithFormat:@"^%@.*", word];

	unsigned rx_options = ONIG_OPTION_IGNORECASE;
	ViRegexp *rx = [ViRegexp regexpWithString:pattern options:rx_options];

	NSMutableArray *buffers = [NSMutableArray array];
	for (ViDocument *doc in [[ViWindowController currentWindowController] documents]) {
		NSString *fn = [[doc fileURL] absoluteString];
		if (fn == nil)
			continue;
		ViRegexpMatch *m = nil;
		if (pattern == nil || (m = [rx matchInString:fn]) != nil) {
			ViCompletion *c;
			if (fuzzySearch)
				c = [ViCompletion completionWithContent:fn fuzzyMatch:m];
			else {
				c = [ViCompletion completionWithContent:fn];
				c.prefixLength = wordlen;
			}
			[buffers addObject:c];
		}
	}

	return buffers;
}

@end
