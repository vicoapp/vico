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

/** A scope covering a range of characters.
 *
 */

@interface ViScope : NSObject <NSCopying>
{
	NSRange		 _range;
	NSArray		*_scopes;
	NSDictionary	*_attributes;
}

/** The range of characters this scope covers. */
@property(nonatomic,readwrite) NSRange range;

@property(nonatomic,readwrite,strong) NSArray *scopes;
@property(nonatomic,readwrite,strong) NSDictionary *attributes;

+ (ViScope *)scopeWithScopes:(NSArray *)scopesArray range:(NSRange)aRange;
- (ViScope *)initWithScopes:(NSArray *)scopesArray range:(NSRange)aRange;

/** @name Matching scope selectors */

/** Match against a scope selector.
 * @param scopeSelector The scope selector.
 */
- (u_int64_t)match:(NSString *)scopeSelector;

/** Returns the best matching scope selector.
 * @param scopeSelectors An array of scope selectors to match.
 * @returns The scope selector with the highest matching rank.
 */
- (NSString *)bestMatch:(NSArray *)scopeSelectors;

- (int)compareBegin:(ViScope *)otherContext;

- (BOOL)addScopeComponent:(NSString *)scopeComponent;

@end
