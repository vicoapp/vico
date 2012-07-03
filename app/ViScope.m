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

#import "ViScope.h"
#import "NSString-scopeSelector.h"

@implementation ViScope

@synthesize range = _range;
@synthesize scopes = _scopes;
@synthesize attributes = _attributes;

+ (ViScope *)scopeWithScopes:(NSArray *)scopesArray range:(NSRange)aRange
{
	return [[[ViScope alloc] initWithScopes:scopesArray range:aRange] autorelease];
}

- (ViScope *)initWithScopes:(NSArray *)scopesArray
                      range:(NSRange)aRange
{
	if ((self = [super init]) != nil) {
		_scopes = [scopesArray retain]; // XXX: retain or copy?
		_range = aRange;
	}
	return self;
}

- (void)dealloc
{
	[_scopes release];
	[_attributes release];
	[super dealloc];
}

- (int)compareBegin:(ViScope *)otherContext
{
	if (self == otherContext)
		return 0;

	if (_range.location < otherContext.range.location)
		return -1;
	if (_range.location > otherContext.range.location)
		return 1;

	if (_range.length > otherContext.range.length)
		return -1;
	if (_range.length < otherContext.range.length)
		return 1;

	return 0;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViScope %p %@: %@>",
	    self, NSStringFromRange(_range),
	    [_scopes componentsJoinedByString:@" "]];
}

- (id)copyWithZone:(NSZone *)zone
{
	return [[[self class] allocWithZone:zone] initWithScopes:_scopes range:_range];
}

- (u_int64_t)match:(NSString *)scopeSelector
{
	if (scopeSelector == nil)
		return 1ULL;
	return [scopeSelector matchesScopes:_scopes];
}

- (NSString *)bestMatch:(NSArray *)scopeSelectors
{
	NSString *foundScopeSelector = nil;
	NSString *scopeSelector;
	u_int64_t highest_rank = 0;

	for (scopeSelector in scopeSelectors) {
		u_int64_t rank = [self match:scopeSelector];
		if (rank > highest_rank) {
			foundScopeSelector = scopeSelector;
			highest_rank = rank;
		}
	}

	return foundScopeSelector;
}

- (BOOL)addScopeComponent:(NSString *)scopeComponent
{
	if (![_scopes containsObject:scopeComponent]) {
		[self setScopes:[_scopes arrayByAddingObject:scopeComponent]];
		return YES;
	}
	return NO;
}

@end

