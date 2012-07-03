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

#import "TestScopeSelectors.h"
#import "NSString-scopeSelector.h"

#define COMPARE(a, op, b) STAssertTrue([a matchesScopes:scopeCString] op [b matchesScopes:scopeCString], nil)

@implementation TestScopeSelectors

- (void)setUp
{
	scopeCString = [NSArray arrayWithObjects:
			@"source.c",
			@"string.quoted.double.c",
			@"punctuation.definition.string.begin.c",
			nil];

	scopeObjCString = [NSArray arrayWithObjects:
		 @"source.objc",
		 @"meta.implementation.objc",
		 @"meta.scope.implementation.objc",
		 @"meta.function-with-body.objc",
		 @"meta.block.c",
		 @"meta.bracketed.objc",
		 @"meta.function-call.objc",
		 @"string.quoted.double.objc",
		 nil];

	scopeObjC = [NSArray arrayWithObjects:
		 @"source.objc",
		 @"meta.implementation.objc",
		 @"meta.scope.implementation.objc",
		 @"meta.function-with-body.objc",
		 @"meta.block.c",
		 nil];

	scopeObjCpp = [NSArray arrayWithObjects:
		 @"source.objc++",
		 @"meta.implementation.objc++",
		 @"meta.scope.implementation.objc++",
		 @"meta.function-with-body.objc++",
		 @"meta.block.c",
		 nil];
}

/* The rank is calculated according to the rules in the TextMate manual, section 13.5:
 *
 * "The winner is the scope selector which (in order of precedence):
 *
 * 1. Match the element deepest down in the scope e.g. string wins over source.php
 *    when the scope is source.php string.quoted.
 *
 * 2. Match most of the deepest element e.g. string.quoted wins over string.
 *
 * 3. Rules 1 and 2 applied again to the scope selector when removing the deepest
 *    element (in the case of a tie), e.g. text source string wins over source string."
 *
 *
 *
 * - A match is given 10^18 points for each depth down the scope stack.
 * - Another 10^<depth> points is given for each additional part of the scope that is matched.
 * - 1 extra point is given for each extra descendant scope.
 * - The empty scope selector gets 1 point.
 * - A non-match has a rank of 0.
 *
 * All indexes above are 1-based.
 * MAX 16 (17?) depths.
 * MAX 10 parts in each scope selector.
 */

- (void)test010_SimplePrefixMatch
{
	STAssertEquals([@"source" matchesScopes:scopeCString], 1*DEPTH_RANK + 1, nil);
}

- (void)test010_SimplePrefixMatch2
{
	STAssertEquals([@"string" matchesScopes:scopeCString], 2*DEPTH_RANK + 1, nil);
}

- (void)test011_SimplePrefixNonMatch
{
	STAssertEquals([@"keyword" matchesScopes:scopeCString], 0ULL, nil);
}

- (void)test012_DeeperPrefixMatch
{
	STAssertEquals([@"punctuation" matchesScopes:scopeCString], 3*DEPTH_RANK + 1, nil);
}

- (void)test013_PrefixMatchMoreSpecificSameDepth
{
	STAssertEquals([@"string.quoted" matchesScopes:scopeCString], 2*DEPTH_RANK+100 + 1, nil);
}

- (void)test014_DeeperPrefixMatch2
{
	STAssertEquals([@"punctuation.definition" matchesScopes:scopeCString], 3*DEPTH_RANK+1000 + 1, nil);
}

- (void)test014_DeeperPrefixMatch3
{
	STAssertEquals([@"punctuation.definition.string" matchesScopes:scopeCString], 3*DEPTH_RANK + 2000 + 1, nil);
}

- (void)test015_EmptyScopeSelectorMatchesWithLowestRank
{
	STAssertEquals([@"" matchesScopes:scopeCString], 1ULL, nil);
}

- (void)test016_DescendantSelector
{
	STAssertEquals([@"source string" matchesScopes:scopeCString], 2*DEPTH_RANK+2, nil);
}

- (void)test016_DescendantSelectorNoMatch
{
	STAssertEquals([@"source keyword" matchesScopes:scopeCString], 0ULL, nil);
}

- (void)test017_DescendantSelectorMoreSpecific
{
	STAssertEquals([@"source string.quoted" matchesScopes:scopeCString], 2*DEPTH_RANK+100+2, nil);
}

- (void)test018_DescendantSelectorDeeperMatch
{
	STAssertEquals([@"source string punctuation" matchesScopes:scopeCString], 3*DEPTH_RANK+3, nil);
}

- (void)test019_DescendantSelectorDeeperMatchMoreSpecific
{
	STAssertEquals([@"source string.quoted punctuation" matchesScopes:scopeCString], 3*DEPTH_RANK+100+3, nil);
}

- (void)test020_DescendantSelectorDeeperMatchMoreSpecific2
{
	STAssertEquals([@"source.c string punctuation" matchesScopes:scopeCString], 3*DEPTH_RANK+10+3, nil);
}

- (void)test021_AmbiguousMatch
{
	NSArray *scope = [NSArray arrayWithObjects:
		 @"text.html",
		 @"source.c",
		 @"string.quoted.double.c",
		 @"source.c.embedded",
		 @"punctuation.definition.string.begin.c",
		 nil];

	STAssertEquals([@"source.c punctuation" matchesScopes:scope], 5*DEPTH_RANK+10000+2, nil);
}

- (void)test022_ImpossibleMatch
{
	// 4 descendants selector can never match a 3 level scope
	STAssertEquals([@"source string punctuation meta" matchesScopes:scopeCString], 0ULL, nil);
}

- (void)test030_RelativeRanks
{
	COMPARE(@"source", <, @"string");
	COMPARE(@"source string", <, @"punctuation");
	COMPARE(@"source string", <, @"source string punctuation");
	COMPARE(@"string", <, @"source string");
	COMPARE(@"string", <, @"string.quoted");
	COMPARE(@"string.quoted", <, @"punctuation");
	COMPARE(@"source string", <, @"source.c string");
	COMPARE(@"source.c string punctuation", <, @"source string.quoted punctuation");
}

- (void)test031_ExcludedSelectorNonMatch
{
	STAssertEquals([@"source.objc - string - comment" matchesScopes:scopeCString], 0ULL, nil);
}

- (void)test032_ExcludedSelector2
{
	STAssertEquals([@"source.objc - string - comment" matchesScopes:scopeObjC], 1*DEPTH_RANK+10 + 1, nil);
}

- (void)test032_ExcludedSelector2WithoutWhitespace
{
	STAssertEquals([@"source.objc  -string -comment" matchesScopes:scopeObjC], 1*DEPTH_RANK+10 + 1, nil);
}

- (void)test033_GroupedSelectorsMatch
{
	STAssertEquals([@"keyword, string" matchesScopes:scopeCString], 2*DEPTH_RANK + 1, nil);
}

- (void)test033_GroupedSelectorsMatch2
{
	STAssertEquals([@"string, keyword" matchesScopes:scopeCString], 2*DEPTH_RANK + 1, nil);
}

- (void)test034_GroupedSelectorsNonMatch
{
	STAssertEquals([@"keyword, blargh" matchesScopes:scopeCString], 0ULL, nil);
}

- (void)test035_GroupedSelectorsWithExclusions
{
	STAssertEquals([@"source.objc - string - comment, source.objc++ - string - comment" matchesScopes:scopeObjC], 1*DEPTH_RANK+10 + 1, nil);
}

- (void)test036_GroupedSelectorsWithExclusions2
{
	STAssertEquals([@"source.objc - string - comment, source.objc++ - string - comment" matchesScopes:scopeObjCpp], 1*DEPTH_RANK+10 + 1, nil);
}

- (void)test037_GroupedSelectorsWithExclusionsNonMatch
{
	STAssertEquals([@"source.objc - string - comment, source.objc++ - string - comment" matchesScopes:scopeObjCString], 0ULL, nil);
}

- (void)test038_StrictPrefix
{
	NSArray *scope = [NSArray arrayWithObjects:
		 @"source.css",
		 nil];

	STAssertEquals([@"source.c" matchesScopes:scope], 0ULL, nil);
}

- (void)test038_StrictPrefix2
{
	NSArray *scope = [NSArray arrayWithObjects:
		 @"source.c",
		 nil];

	STAssertEquals([@"source.css" matchesScopes:scope], 0ULL, nil);
}

- (void)test039_NonContiguousScopeMatch
{
	NSArray *scope = [NSArray arrayWithObjects:
		 @"source.objc",
		 @"meta.implementation.objc",
		 @"meta.scope.implementation.objc",
		 @"meta.function-with-body.objc",
		 @"meta.block.c",
		 nil];
	STAssertEquals([@"source.objc meta.scope.implementation" matchesScopes:scope],
	    3*DEPTH_RANK + 1*10 + 2*1000 + 2, nil);
}

- (void)test040_BooleanOr
{
	STAssertEquals([@"meta.bracketed.objc | meta.function.objc" matchesScopes:scopeObjCString],
	    6*DEPTH_RANK + 2*1000000 + 1, nil);
}

- (void)test041_BooleanOrSecondMatch
{
	STAssertEquals([@"meta.function.objc | meta.bracketed.objc" matchesScopes:scopeObjCString],
	    6*DEPTH_RANK + 2*1000000 + 1, nil);
}

- (void)test042_BooleanOrInParens
{
	STAssertEquals([@"(meta.bracketed.objc | meta.function.objc)" matchesScopes:scopeObjCString],
	    6*DEPTH_RANK + 2*1000000 + 1, nil);
}

- (void)test050_ChildSelector
{
	STAssertTrue([@"source > string" matchesScopes:scopeCString] > 0ULL, nil);
	STAssertEquals([@"source > string" matchesScopes:scopeObjCString], 0ULL, nil);
}

- (void)test051_LastSelector
{
	STAssertTrue([@"string $" matchesScopes:scopeObjCString] > 0ULL, nil);
	STAssertEquals([@"string $" matchesScopes:scopeCString], 0ULL, nil);
}

- (void)test052_SimplePrefixNonMatch
{
	STAssertEquals([@"source.c.foo.bar" matchesScopes:scopeCString], 0ULL, nil);
}

@end

