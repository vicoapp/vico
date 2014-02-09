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

#import "ViSyntaxContext.h"
#import "ViSyntaxMatch.h"
#import "ViLanguage.h"

@interface ViSyntaxParser : NSObject
{
	// configuration
	ViLanguage	*_language;

	// persistent state
	NSMutableArray	*_continuations;
	NSMutableArray	*_scopeArray;

	// per-request state
	const unichar	*_chars;
	NSUInteger	 _offset;
	ViSyntaxContext	*_context;

	// statistics
	unsigned	 _regexps_tried;
	unsigned	 _regexps_overlapped;
	unsigned	 _regexps_matched;
	unsigned	 _regexps_cached;
}

+ (ViSyntaxParser *)syntaxParserWithLanguage:(ViLanguage *)aLanguage;

- (ViSyntaxParser *)initWithLanguage:(ViLanguage *)aLanguage;
- (NSArray *)updatedScopeArrayWithContext:(ViSyntaxContext *)aContext;

- (void)setContinuation:(NSArray *)continuationMatches forLine:(NSUInteger)lineno;

- (NSArray *)scopesFromMatches:(NSArray *)matches withoutContentForMatch:(ViSyntaxMatch *)skipContentMatch;

- (void)pushContinuations:(NSUInteger)changedLines
           fromLineNumber:(NSUInteger)lineNumber;

- (void)pullContinuations:(NSUInteger)changedLines
           fromLineNumber:(NSUInteger)lineNumber;

- (void)pushScopes:(NSRange)affectedRange;
- (void)pullScopes:(NSRange)affectedRange;

- (void)updateScopeRangesInRange:(NSRange)updateRange;

@end
