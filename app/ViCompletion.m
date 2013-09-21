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

#import "ViCompletion.h"
#import "ViThemeStore.h"
#import "ViCommon.h"
#include "logging.h"

static NSCharacterSet *__separators = nil;
static NSCharacterSet *__ucase = nil;

@implementation ViCompletion

@synthesize content = _content;
@synthesize filterMatch = _filterMatch;
@synthesize prefixLength = _prefixLength;
@synthesize filterIsFuzzy = _filterIsFuzzy;
@synthesize font = _font;
@synthesize location = _location;
@synthesize representedObject = _representedObject;
@synthesize markColor = _markColor;
@synthesize title = _title;
@synthesize isCurrentChoice = _isCurrentChoice;

+ (id)completionWithContent:(NSString *)aString
{
	return [[ViCompletion alloc] initWithContent:aString];
}

+ (id)completionWithContent:(NSString *)aString fuzzyMatch:(ViRegexpMatch *)aMatch
{
	return [[ViCompletion alloc] initWithContent:aString fuzzyMatch:aMatch];
}

- (id)initWithContent:(NSString *)aString
{
	if ((self = [super init]) != nil) {
		_content = [aString copy];
		_font = [NSFont userFixedPitchFontOfSize:12];
		_titleParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		[_titleParagraphStyle setLineBreakMode:NSLineBreakByTruncatingHead];
		_markColor = [NSColor redColor];
		_titleIsDirty = YES;
		_scoreIsDirty = YES;

		if (__separators == nil) {
			__separators = [NSCharacterSet punctuationCharacterSet];
			__ucase = [NSCharacterSet uppercaseLetterCharacterSet];
		}
	}
	return self;
}

- (id)initWithContent:(NSString *)aString fuzzyMatch:(ViRegexpMatch *)aMatch
{
	if ((self = [self initWithContent:aString]) != nil) {
		_filterMatch = aMatch;
		_filterIsFuzzy = YES;
	}
	return self;
}


- (void)updateTitle
{
	_titleIsDirty = NO;

	if (_prefixLength > [_content length])
		return;

	NSRange matchedRange = NSMakeRange(0, _prefixLength);
	if (_filterMatch && !_filterIsFuzzy) {
		matchedRange.length = _filterMatch.rangeOfMatchedString.length;
	}

	NSColor *gray = [NSColor grayColor];

	[self setTitle:[[NSMutableAttributedString alloc] initWithString:_content]];

	[_title addAttribute:NSFontAttributeName
		       value:_font
		       range:NSMakeRange(0, [_title length])];

	[_title addAttribute:NSParagraphStyleAttributeName
		       value:_titleParagraphStyle
		       range:NSMakeRange(0, [_title length])];

	NSRange completionRange = NSMakeRange(matchedRange.length, _title.length - matchedRange.length);
	if (_isCurrentChoice) {
		/* Make it white so we can read easier on the selected background. */
		[_title addAttribute:NSForegroundColorAttributeName
			       value:[NSColor whiteColor]
			       range:completionRange];

		if (matchedRange.length > 0) {
			[_title addAttribute:NSForegroundColorAttributeName
					   value:[NSColor lightGrayColor]
					   range:matchedRange];
		}
	} else {
		[_title addAttribute:NSForegroundColorAttributeName
			       value:[NSColor blackColor]
			       range:completionRange];

		if (matchedRange.length > 0) {
			[_title addAttribute:NSForegroundColorAttributeName
					   value:gray
					   range:matchedRange];
		}
	}

	if (_filterMatch && _filterIsFuzzy) {
		/* Mark sub-matches with bold red. */
		NSFont *boldFont = [[NSFontManager sharedFontManager]
		    convertFont:_font
		    toHaveTrait:NSBoldFontMask];
		/*NSFont *boldFont = [[NSFontManager sharedFontManager]
		    convertWeight:12 ofFont:_font];*/

		NSUInteger offset = [_filterMatch rangeOfMatchedString].location;
		NSUInteger i;
		for (i = 1; i <= [_filterMatch count]; i++) {
			NSRange range = [_filterMatch rangeOfSubstringAtIndex:i];
			if (range.length > 0 && range.location != NSNotFound) {
				range.location -= offset;
				[_title addAttribute:NSFontAttributeName
					       value:boldFont
					       range:range];
				[_title addAttribute:NSForegroundColorAttributeName
					       value:_markColor
					       range:range];
			}
		}
	}
}

/* based on
 * http://www.emacswiki.org/emacs/el-swank-fuzzy.el
 */
- (void)calcScore
{
	_scoreIsDirty = NO;

	NSUInteger flen = [_content length]; /* full length */
	NSUInteger slen = 0; /* short length */
	NSUInteger offset = [_filterMatch rangeOfMatchedString].location;
	NSUInteger i;
	double match_score = 0, prev_score = 0;
	NSUInteger prev_pos = 0;
	for (i = 1; i <= [_filterMatch count]; i++) {
		NSRange range = [_filterMatch rangeOfSubstringAtIndex:i];
		if (range.location == NSNotFound || range.length == 0)
			continue;
		NSUInteger pos = range.location - offset;
		slen += range.length;

		/* Letters are given scores based on their position
		 * in the string.  Letters at the beginning of a string
		 * or after a prefix letter at the beginning of a
		 * string are scored highest.  Letters after a word
		 * separator such as #\- are scored next highest.
		 * Letters at the end of a string or before a suffix
		 * letter at the end of a string are scored medium,
		 * and letters anywhere else are scored low.
		 */

		double base_score = 1.0;
		if (pos == 0)
			base_score = 10.0;
		else if (pos == flen - 1)
			base_score = 6.0;
		else if ([__separators characterIsMember:[_content characterAtIndex:pos - 1]] ||
		         [__ucase characterIsMember:[_content characterAtIndex:pos]])
			base_score = 8.0;
		else if ([__separators characterIsMember:[_content characterAtIndex:pos]])
			base_score = 1.0;
		else if ([__separators characterIsMember:[_content characterAtIndex:pos + 1]])
			base_score = 4.0;

		DEBUG(@"scoring match at %lu (%@) in [%@] with base %lf",
		    pos, NSStringFromRange(range), _content, base_score);

		/*
		 * If a letter is directly after another matched
		 * letter, and its intrinsic value in that position
		 * is less than a percentage of the previous letter's
		 * value, it will use that percentage instead.
		 */
		double char_score = 0;
		if (i > 1 && prev_pos == pos - 1) {
			char_score = 0.85 * prev_score;
			if (char_score < base_score)
				char_score = base_score;
		} else
			char_score = base_score;
		match_score += char_score;

		prev_score = char_score;
		prev_pos = pos;
	}

	double length_score = (double)15.0 / (double)(1 + flen - slen);
	DEBUG(@"match score is %lf, length score is %lf", match_score, length_score);
	_score = match_score + length_score;
}

- (void)setFilterIsFuzzy:(BOOL)aFlag
{
	_filterIsFuzzy = aFlag;
	_titleIsDirty = YES;
	_scoreIsDirty = YES;
}

- (void)setFilterMatch:(ViRegexpMatch *)m
{
	_filterMatch = m;
	_titleIsDirty = YES;
	_scoreIsDirty = YES;
}

- (void)setPrefixLength:(NSUInteger)len
{
	_prefixLength = len;
	_titleIsDirty = YES;
}

- (void)setFont:(NSFont *)aFont
{
	_font = aFont;
	_titleIsDirty = YES;
}

- (void)setIsCurrentChoice:(BOOL)isChoice {
	_isCurrentChoice = isChoice;
	_titleIsDirty = YES;
}

- (double)score
{
	if (_scoreIsDirty)
		[self calcScore];
	return _score;
}

- (NSAttributedString *)title
{
	if (_titleIsDirty)
		[self updateTitle];
	return _title;
}

- (NSUInteger)hash
{
	return [_content hash];
}

- (BOOL)isEqual:(id)obj
{
	if (obj == self)
		return YES;
	if ([obj isKindOfClass:[self class]] &&
	    [_content isEqualToString:[(ViCompletion *)obj content]])
		return YES;
	return NO;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<ViCompletion %@/%lu ~%@>", _content, _prefixLength, _filterMatch];
}

@end
