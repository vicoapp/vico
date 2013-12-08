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

#import "ExMap.h"
#import "NSString-additions.h"
#import "NSString-scopeSelector.h"
#include "logging.h"

@implementation ExMapping

@synthesize names = _names;
@synthesize syntax = _syntax;
@synthesize scopeSelector = _scopeSelector;
@synthesize expression = _expression;
@synthesize action = _action;
@synthesize completion = _completion;

- (ExMapping *)initWithNames:(NSArray *)namesArray
					  syntax:(NSString *)aSyntax
					   scope:(NSString *)aScopeSelector
			  parameterNames:(NSArray *)aParameterNamesArray
			   documentation:(NSString *)aDocumentationString
{
	if ((self = [super init]) != nil) {
		if ([namesArray count] == 0) {
			INFO(@"%s", "missing ex mapping name");
			return nil;
		}
		_names = [namesArray mutableCopy];
		_syntax = [aSyntax copy];
		_scopeSelector = [aScopeSelector copy] ?: @"";
		_parameterNames = [aParameterNamesArray copy];
		_documentation = [aDocumentationString copy];
	}
	return self;
}

- (ExMapping *)initWithNames:(NSArray *)namesArray
					  syntax:(NSString *)aSyntax
                  expression:(NuBlock *)anExpression
                       scope:(NSString *)aScopeSelector
			  parameterNames:(NSArray *)aParameterNamesArray
			   documentation:(NSString *)aDocumentationString
{
	if ((self = [self initWithNames:namesArray syntax:aSyntax scope:aScopeSelector parameterNames:aParameterNamesArray documentation:aDocumentationString]) != nil) {
		_expression = anExpression;
	}
	return self;
}

- (ExMapping *)initWithNames:(NSArray *)namesArray
					  syntax:(NSString *)aSyntax
                      action:(SEL)anAction
                       scope:(NSString *)aScopeSelector
			  parameterNames:(NSArray *)aParameterNamesArray
			   documentation:(NSString *)aDocumentationString
{
	if ((self = [self initWithNames:namesArray syntax:aSyntax scope:aScopeSelector parameterNames:aParameterNamesArray documentation:aDocumentationString]) != nil) {
		_action = anAction;
	}
	return self;
}


- (NSString *)name
{
	return [_names objectAtIndex:0];
}

- (void)addAlias:(NSString *)aName
{
	/* XXX: when adding an alias, shouldn't we check for duplicate mappings in the same map? */
	[_names addObject:aName];
}

- (void)removeAlias:(NSString *)aName
{
	if ([_names count] > 1)
		[_names removeObject:aName];
}

- (int)matchesName:(NSString *)name exactly:(BOOL)exactMatch
{
	NSUInteger len = [name length];
	int match = 0;
	for (NSString *n in _names) {
		if (exactMatch ? [name isEqualToString:n] : [n hasPrefix:name]) {
			if (len == [n length])
				return 2; /* exact match */
			match = 1;
		}
	}
	return match;
}

- (NSString *)syntaxHintWithCommandHint:(NSString *)commandHint
{
	__block NSUInteger currentParameterIndex = 0;
	NSString * (^currentParameterOr)(NSString *) = ^NSString *(NSString *defaultName) {
		return (currentParameterIndex < [_parameterNames count]) ?
					_parameterNames[currentParameterIndex] :
					defaultName;
	};

	NSMutableString *syntaxString = [NSMutableString string];
	if ([_syntax occurrencesOfCharacter:'r'] > 0) {
		[syntaxString appendFormat:@"[%@]", currentParameterOr(@"range"), nil];
		currentParameterIndex++;
	}

	[syntaxString appendString:commandHint];

	if ([_syntax occurrencesOfCharacter:'!'] > 0) {
		[syntaxString appendString:@"[!]"];
	}

	if ([_syntax occurrencesOfCharacter:'+'] > 0) {
		[syntaxString appendFormat:@" [+%@]", currentParameterOr(@"command"), nil];
		currentParameterIndex++;
	}

	NSRange argumentRange = [_syntax rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"eE"]];
	if (argumentRange.location != NSNotFound) {
		unichar character = [_syntax characterAtIndex:argumentRange.location];

		NSString *format = (character == 'e') ? @" [%@]" : @" {%@}";

		if ([_syntax occurrencesOfCharacter:'1'] == 0) {
			format = [format stringByAppendingString:@"+"];
		}
		[syntaxString appendFormat:format, currentParameterOr(@"argument"), nil];
		currentParameterIndex++;
	}

	if ([_syntax occurrencesOfCharacter:'R'] > 0) {
		[syntaxString appendFormat:@" [%@]", currentParameterOr(@"register"), nil];
		currentParameterIndex++;
	}

	NSRange lineRange = [_syntax rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"lL"]];
	if (lineRange.location != NSNotFound) {
		unichar character = [_syntax characterAtIndex:lineRange.location];

		NSString *format = (character == 'l') ? @" [%@]" : @" {%@}";

		[syntaxString appendFormat:format, currentParameterOr(@"line"), nil];
		currentParameterIndex++;
	}

	if ([_syntax occurrencesOfCharacter:'~'] > 0) {
		[syntaxString appendFormat:@"/%@", currentParameterOr(@"regexp"), nil];
		currentParameterIndex++;
		[syntaxString appendFormat:@"/%@", currentParameterOr(@"replace"), nil];
		currentParameterIndex++;
		[syntaxString appendFormat:@"[/[%@]]", currentParameterOr(@"flags"), nil];
		currentParameterIndex++;
	}

	if ([_syntax occurrencesOfCharacter:'/'] > 0) {
		[syntaxString appendFormat:@"/%@", currentParameterOr(@"regexp"), nil];
		currentParameterIndex++;
		[syntaxString appendFormat:@"[/[%@]]", currentParameterOr(@"flags"), nil];
		currentParameterIndex++;
	}

	if ([_syntax occurrencesOfCharacter:'c'] > 0) {
		[syntaxString appendFormat:@" [%@]", currentParameterOr(@"count"), nil];
		currentParameterIndex++;
	}
	
	return [NSString stringWithString:syntaxString];
}

- (NSString *)description
{
	if ([_scopeSelector length] > 0)
		return [NSString stringWithFormat:@"<ExMapping %@(%@): %@>",
		    self.name, _scopeSelector, _expression ? [_expression stringValue] : NSStringFromSelector(_action)];
	else
		return [NSString stringWithFormat:@"<ExMapping %@: %@>",
		    self.name, _expression ? [_expression stringValue] : NSStringFromSelector(_action)];
}

@end

@implementation ExMap

@synthesize mappings = _mappings;

- (ExMap *)init
{
	if ((self = [super init]) != nil) {
		_mappings = [[NSMutableArray alloc] init];
	}
	return self;
}


+ (ExMap *)defaultMap
{
	static ExMap *__defaultMap = nil;
	if (__defaultMap == nil)
		__defaultMap = [[ExMap alloc] init];
	return __defaultMap;
}

- (ExMapping *)lookup:(NSString *)aString
	    withScope:(ViScope *)scope
{
	ExMapping *candidate = nil;
	NSMutableSet *dups = nil;
	u_int64_t rank = 0;
	BOOL exactMatch = NO;

	if ([aString length] == 0)
		return nil;

	for (ExMapping *m in _mappings) {
		/*
		 * Check if the name match. We start with partial
		 * matching. If an exact match is found, we continue
		 * only considering exact matches.
		 */
		int match;
		if ((match = [m matchesName:aString exactly:exactMatch]) > 0) {
			if (!exactMatch && match == 2) {
				exactMatch = YES;
				rank = [m.scopeSelector match:scope];
				candidate = m;
				DEBUG(@"got exact match %@ w/rank %lu", candidate, rank);
				dups = nil;
				/* An exact match overrides any partial command with a higher rank. */
				continue;
			}

			u_int64_t r = [m.scopeSelector match:scope];
			if (r > rank) {
				rank = r;
				candidate = m;
				dups = nil;
			} else if (r == rank) {
				if (dups == nil)
					dups = [NSMutableSet set];
				[dups addObject:m];
			}
		}
	}

	if (dups) {
		[dups addObject:candidate];
		INFO(@"ambiguous command; could be %@", dups);
	}

	DEBUG(@"%@ -> %@", aString, candidate);
	return candidate;
}

- (ExMapping *)lookup:(NSString *)aString
{
	return [self lookup:aString withScope:nil];
}

- (void)addMapping:(ExMapping *)mapping
{
	DEBUG(@"adding ex command %@", mapping);
	ExMapping *old = nil;
	for (ExMapping *m in _mappings) {
		if ([m.scopeSelector isEqualToString:mapping.scopeSelector]) {
			for (NSString *n in mapping.names) {
				if ([m matchesName:n exactly:YES]) {
					old = m;
					break;
				}
			}
		}
		if (old)
			break;
	}

	if (old) {
		DEBUG(@"replacing previous ex command %@ w/same scope %@", old, old.scopeSelector);
		[_mappings removeObject:old];
	}
	[_mappings addObject:mapping];
}

- (ExMapping *)define:(id)aName
			   syntax:(NSString *)aSyntax
				   as:(id)implementation
				scope:(NSString *)aScopeSelector
	   parameterNames:(id)aParameterNamesList
		documentation:(NSString *)aDocumentationString
{
	ExMapping *m = nil;

	NSArray *parameterNames = aParameterNamesList;
	if ([aParameterNamesList isKindOfClass:[NuCell class]]) {
		parameterNames = [aParameterNamesList array];
	} else if (! aParameterNamesList || aParameterNamesList == [NSNull null]) {
		parameterNames = [NSArray array];
	} else if (! [aParameterNamesList isKindOfClass:[NSArray class]]) {
		INFO(@"Invalid parameter names class %@", NSStringFromClass([aParameterNamesList class]));
		return nil;
	}

	NSArray *names = aName;
	if ([aName isKindOfClass:[NuCell class]])
		names = [aName array];
	else if ([aName isKindOfClass:[NSString class]])
		names = [NSArray arrayWithObject:aName];
	else if (![aName isKindOfClass:[NSArray class]]) {
		INFO(@"Invalid mapping name class %@", NSStringFromClass([aName class]));
		return nil;
	}

	if ([implementation isKindOfClass:[NSString class]])
		m = [[ExMapping alloc] initWithNames:names
									  syntax:aSyntax
									  action:NSSelectorFromString(implementation)
									   scope:aScopeSelector
							  parameterNames:parameterNames
							   documentation:aDocumentationString];
	else if ([implementation isKindOfClass:[NuBlock class]])
		m = [[ExMapping alloc] initWithNames:names
									  syntax:aSyntax
								  expression:implementation
									   scope:aScopeSelector
							  parameterNames:parameterNames
							   documentation:aDocumentationString];
	else {
		INFO(@"Invalid mapping implementation class %@",
			NSStringFromClass([implementation class]));
		return nil;
	}

	if (m) {
		[self addMapping:m];
	}

	return m;
}

- (ExMapping *)define:(id)aName
			   syntax:(NSString *)aSyntax
				   as:(id)implementation
	   parameterNames:(id)aParameterNamesList
		documentation:(NSString *)aDocumentationString
{
	return [self define:aName
				 syntax:aSyntax
					 as:implementation
				  scope:nil
		 parameterNames:aParameterNamesList
		  documentation:aDocumentationString];
}

@end

