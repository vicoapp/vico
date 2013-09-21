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

#import "ViTheme.h"
#import "NSString-scopeSelector.h"
#import "logging.h"

@implementation ViTheme

+ (id)themeWithPath:(NSString *)aPath
{
	return [[ViTheme alloc] initWithPath:aPath];
}

- (id)initWithPath:(NSString *)aPath
{
	self = [super init];
	if (self == nil)
		return nil;

	_theme = [[NSMutableDictionary alloc] initWithContentsOfFile:aPath];
	if (![_theme isKindOfClass:[NSDictionary class]]) {
		INFO(@"failed to parse theme %@", aPath);
		return nil;
	}

	if ([[self name] length] == 0) {
		INFO(@"Missing 'name' in theme %@", aPath);
		return nil;
	}

	_scopeSelectorCache = [[NSMutableDictionary alloc] init];
	_themeAttributes = [[NSMutableDictionary alloc] init];
	NSArray *preferences = [_theme objectForKey:@"settings"];
	for (NSDictionary *preference in preferences) {
		if ([preference objectForKey:@"name"] == nil) {
			/* Settings for the default scope. */
			NSMutableDictionary *tmp = [preference objectForKey:@"settings"];
			if (![tmp isKindOfClass:[NSDictionary class]])
				continue;
			_defaultSettings = tmp;

			id value;
			if ((value = [_defaultSettings objectForKey:@"smartPairMatch"]) != nil && [value isKindOfClass:[NSDictionary class]]) {
				/* Settings for the matching pair highlight. */
				_smartPairMatchAttributes = [[NSMutableDictionary alloc] init];
				[ViBundle normalizeSettings:value intoDictionary:_smartPairMatchAttributes];
				if ([_smartPairMatchAttributes count] == 0) {
					_smartPairMatchAttributes = nil;
				}
			}

			[ViBundle normalizePreference:preference intoDictionary:_defaultSettings];
			continue;
		}

		NSString *scopeSelector = [preference objectForKey:@"scope"];
		if (scopeSelector == nil)
			continue;

		NSMutableDictionary *attrs = [[NSMutableDictionary alloc] init];	
		[ViBundle normalizePreference:preference intoDictionary:attrs];

		[_themeAttributes setObject:attrs forKey:scopeSelector];
	}

	return self;
}


- (NSString *)name
{
	return [_theme objectForKey:@"name"];
}

- (NSDictionary *)smartPairMatchAttributes
{
	if (_smartPairMatchAttributes == nil) {
		// _smartPairMatchAttributes = [NSDictionary dictionaryWithObject:[self selectionColor]
		// 						        forKey:NSBackgroundColorAttributeName];
		_smartPairMatchAttributes = [NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:NSUnderlinePatternSolid | NSUnderlineStyleDouble]
									 forKey:NSUnderlineStyleAttributeName];
	}
	return _smartPairMatchAttributes;
}

/*
 * From the textmate manual:
 * "For themes and preference items, the winner is undefined when
 *  multiple items use the same scope selector, though this is on
 *  a per-property basis. So for example if one theme item sets the
 *  background to blue for string.quoted and another theme item sets
 *  the foreground to white, again for string.quoted, the result
 *  would be that the foreground was taken from the latter item and
 *  background from the former."
 */
- (void)matchAttributes:(NSDictionary *)matchAttributes
               forScope:(ViScope *)scope
         intoDictionary:(NSMutableDictionary *)attributes
              rankState:(NSMutableDictionary *)attributesRank
{
	NSString *scopeSelector;
	for (scopeSelector in matchAttributes) {
		u_int64_t rank = [scopeSelector match:scope];
		if (rank > 0) {
			NSDictionary *attrs = [matchAttributes objectForKey:scopeSelector];
			NSString *attrKey;
			for (attrKey in attrs) {
				u_int64_t prevRank = [[attributesRank objectForKey:attrKey] unsignedLongLongValue];
				if (rank > prevRank) {
					DEBUG(@"scope selector [%@] matches scope %@ with rank %llu > %llu, setting %@", scopeSelector, scope, rank, prevRank, attrKey);
					[attributes setObject:[attrs objectForKey:attrKey] forKey:attrKey];
					[attributesRank setObject:[NSNumber numberWithUnsignedLongLong:rank] forKey:attrKey];
				}
			}
		}
	}
}

/* Return attributes (fore/background colors, underline, oblique) that are specified
 * by the theme by matching against the scope selectors.
 *
 * Returns nil if no attributes are applicable.
 */
- (NSDictionary *)attributesForScope:(ViScope *)scope inBundle:(ViBundle *)bundle
{
	NSString *key = [[scope scopes] componentsJoinedByString:@" "];
	NSMutableDictionary *attributes = [_scopeSelectorCache objectForKey:key];
	if (attributes)
		return [attributes count] == 0 ? nil : attributes;

	attributes = [NSMutableDictionary dictionary];
	NSMutableDictionary *attributesRank = [NSMutableDictionary dictionary];

	// Set default colors
	[attributes setObject:[self foregroundColor] forKey:NSForegroundColorAttributeName];
	[attributes setObject:[self backgroundColor] forKey:NSBackgroundColorAttributeName];

	[self matchAttributes:_themeAttributes
		     forScope:scope
	       intoDictionary:attributes
		    rankState:attributesRank];

	/*
	 * Bundle preferences can override/add theme attributes for certain scopes.
	 * The Diff bundle does this for example.
	 */
	if (bundle != nil) {
		NSArray *prefs = [NSArray arrayWithObjects:NSBackgroundColorAttributeName,
		    NSForegroundColorAttributeName,
		    NSUnderlineStyleAttributeName,
		    NSObliquenessAttributeName,
		    NSStrokeWidthAttributeName,
		    nil];
		NSDictionary *bundlePrefs = [bundle preferenceItems:prefs];
		if (bundlePrefs)
			[self matchAttributes:bundlePrefs forScope:scope intoDictionary:attributes rankState:attributesRank];
	}

	// Backgrounds with alpha is not supported, so blend the background colors together.
	NSColor *bg = [attributes objectForKey:NSBackgroundColorAttributeName];
	if (bg) {
		NSColor *new_bg = [[self backgroundColor] blendedColorWithFraction:[bg alphaComponent] ofColor:bg];
		[attributes setObject:new_bg forKey:NSBackgroundColorAttributeName];
	}

	// cache it
	[_scopeSelectorCache setObject:attributes forKey:key];

	return attributes;
}

- (NSColor *)colorWithName:(NSString *)colorName orDefault:(NSColor *)defaultColor
{
	NSString *rgb = [_defaultSettings objectForKey:colorName];
	NSColor *color = nil;
	if (rgb)
		color = [ViBundle hashRGBToColor:rgb];
	return color ?: defaultColor;
}

- (NSColor *)backgroundColor
{
	if (_backgroundColor == nil) {
		_backgroundColor = [_defaultSettings objectForKey:NSBackgroundColorAttributeName];
		if (_backgroundColor == nil)
			_backgroundColor = [[NSColor whiteColor] colorWithAlphaComponent:1.0];
	}
	return _backgroundColor;
}

- (NSColor *)foregroundColor
{
	if (_foregroundColor == nil) {
		_foregroundColor = [_defaultSettings objectForKey:NSForegroundColorAttributeName];
		if (_foregroundColor == nil)
			_foregroundColor = [[NSColor blackColor] colorWithAlphaComponent:1.0];
	}
	return _foregroundColor;
}

- (NSColor *)lineHighlightColor
{
	if (_lineHighlightColor == nil) {
		_lineHighlightColor = [self colorWithName:@"lineHighlight"
						orDefault:[_caretColor colorWithAlphaComponent:0.1]];
	}
	return _lineHighlightColor;
}

- (NSColor *)caretColor
{
	if (_caretColor == nil) {
		NSColor *defaultCaretColor = [NSColor colorWithCalibratedRed:0.2
								       green:0.2
									blue:0.2
								       alpha:0.5];
		_caretColor = [self colorWithName:@"caret" orDefault:defaultCaretColor];
		_caretColor = [_caretColor colorWithAlphaComponent:0.5];
	}
	return _caretColor;
}

- (NSColor *)selectionColor
{
	if (_selectionColor == nil) {
		NSColor *bg = [self colorWithName:@"selection" orDefault:[[NSColor blueColor] colorWithAlphaComponent:0.5]];
		_selectionColor = [[self backgroundColor] blendedColorWithFraction:[bg alphaComponent] ofColor:bg];
	}
	return _selectionColor;
}

- (NSColor *)invisiblesColor
{
	if (_invisiblesColor == nil) {
		NSColor *defaultInvisiblesColor = [NSColor colorWithCalibratedRed:0.2
								            green:0.2
									     blue:0.2
								            alpha:0.5];
		_invisiblesColor = [self colorWithName:@"invisibles" orDefault:defaultInvisiblesColor];
		if ([_invisiblesColor alphaComponent] > 0.5)
			_invisiblesColor = [_invisiblesColor colorWithAlphaComponent:0.5];
	}
	return _invisiblesColor;
}

- (NSDictionary *)invisiblesAttributes
{
	return [NSDictionary dictionaryWithObject:[self invisiblesColor]
	                                   forKey:NSForegroundColorAttributeName];
}

- (BOOL)hasDarkBackground
{
	return ([[self backgroundColor] brightnessComponent] < 0.6);
}

- (NSString *)description
{
	return [_theme description];
}

@end
