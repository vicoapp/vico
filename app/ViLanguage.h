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

#import "ViRegexp.h"
#import "ViScope.h"

@class ViBundle;

/** A language syntax.
 */
@interface ViLanguage : NSObject
{
	__weak ViBundle		*_bundle;	// XXX: not retained!
	NSMutableDictionary	*_language;
	NSMutableArray		*_languagePatterns;
	BOOL			 _compiled;
	ViScope			*_scope;
	NSString		*_uuid;
}

@property(nonatomic,readonly) NSString *uuid;

@property(nonatomic,readonly) __weak ViBundle *bundle;

/** The top-level scope of the language. */
@property(nonatomic,readonly) ViScope *scope;

@property (weak, nonatomic, readonly) NSString *firstLineMatch;

/**
 * @returns  The scope name of the language.
 */
@property (weak, nonatomic, readonly) NSString *name;

- (id)initWithPath:(NSString *)aPath forBundle:(ViBundle *)aBundle;
- (NSArray *)fileTypes;

/**
 * @returns The display name of the language.
 */
@property (weak, nonatomic, readonly) NSString *displayName;

@property (weak, nonatomic, readonly) NSString *injectionSelector;

- (NSArray *)patterns;
- (NSArray *)expandedPatternsForPattern:(NSMutableDictionary *)pattern;
- (NSArray *)expandedPatternsForPattern:(NSMutableDictionary *)pattern baseLanguage:(ViLanguage *)baseLanguage;
- (ViRegexp *)compileRegexp:(NSString *)pattern
 withBackreferencesToRegexp:(ViRegexpMatch *)beginMatch
                  matchText:(const unichar *)matchText;

@end
