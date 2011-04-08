#import "ViCompletion.h"
#import "ViThemeStore.h"
#include "logging.h"

@interface ViCompletion (private)
- (void)updateTitle;
- (void)calcScore;
@end

@implementation ViCompletion

@synthesize title, content, filter, prefixLength, filterIsFuzzy, font, location, score;

+ (id)completionWithContent:(NSString *)aString prefixLength:(NSUInteger)aLength
{
	return [[ViCompletion alloc] initWithContent:aString prefixLength:aLength];
}

+ (id)completionWithContent:(NSString *)aString fuzzyMatch:(ViRegexpMatch *)aMatch
{
	return [[ViCompletion alloc] initWithContent:aString fuzzyMatch:aMatch];
}

- (id)initWithContent:(NSString *)aString prefixLength:(NSUInteger)aLength
{
	if ((self = [super init]) != nil) {
		content = aString;
		prefixLength = aLength;
		font = [ViThemeStore font];
		[self updateTitle];
	}
	return self;
}

- (id)initWithContent:(NSString *)aString fuzzyMatch:(ViRegexpMatch *)aMatch
{
	if ((self = [super init]) != nil) {
		content = aString;
		filter = aMatch;
		filterIsFuzzy = YES;
		font = [ViThemeStore font];
		[self updateTitle];
		[self calcScore];
	}
	return self;
}

- (void)updateTitle
{
	NSRange grayRange = NSMakeRange(0, prefixLength);
	if (filter && !filterIsFuzzy)
		grayRange.length = filter.rangeOfMatchedString.length;
	NSColor *gray = [NSColor grayColor];

	title = [[NSMutableAttributedString alloc] initWithString:content];
	if (grayRange.length > 0)
		[title addAttribute:NSForegroundColorAttributeName
			      value:gray
			      range:grayRange];

	[title addAttribute:NSFontAttributeName
		      value:font
		      range:NSMakeRange(0, [title length])];

	if (filter && filterIsFuzzy) {
		/* Mark sub-matches with bold. */
		NSFont *boldFont = [[NSFontManager sharedFontManager]
		    convertFont:font
		    toHaveTrait:NSBoldFontMask];
		/*NSFont *boldFont = [[NSFontManager sharedFontManager]
		    convertWeight:12 ofFont:font];*/
		NSColor *markColor = [NSColor redColor];

		NSUInteger offset = [filter rangeOfMatchedString].location;
		NSUInteger i;
		for (i = 1; i <= [filter count]; i++) {
			NSRange range = [filter rangeOfSubstringAtIndex:i];
			if (range.length > 0 && range.location != NSNotFound) {
				range.location -= offset;
				[title addAttribute:NSFontAttributeName
					      value:boldFont
					      range:range];
				[title addAttribute:NSForegroundColorAttributeName
					      value:markColor
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
	NSUInteger flen = [content length]; /* full length */
	NSUInteger slen; /* short length */
	NSUInteger offset = [filter rangeOfMatchedString].location;
	NSCharacterSet *separators = [NSCharacterSet punctuationCharacterSet];
	NSCharacterSet *ucase = [NSCharacterSet uppercaseLetterCharacterSet];
	NSCharacterSet *lcase = [NSCharacterSet lowercaseLetterCharacterSet];
	NSUInteger i;
	double match_score = 0, prev_score = 0;
	NSUInteger prev_pos = 0;
	for (i = 1; i <= [filter count]; i++) {
		NSRange range = [filter rangeOfSubstringAtIndex:i];
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
		else if ([separators characterIsMember:[content characterAtIndex:pos - 1]])
			base_score = 8.0;
		else if ([separators characterIsMember:[content characterAtIndex:pos]])
			base_score = 1.0;
		else if ([separators characterIsMember:[content characterAtIndex:pos + 1]])
			base_score = 4.0;
		else if ([ucase characterIsMember:[content characterAtIndex:pos]] &&
		         [lcase characterIsMember:[content characterAtIndex:pos-1]] &&
		         [lcase characterIsMember:[content characterAtIndex:pos+1]])
			base_score = 8.0;

		DEBUG(@"scoring match at %lu (%@) in [%@] with base %lf",
		    pos, NSStringFromRange(range), content, base_score);

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

	double length_score = 10.0 / (1 + flen - slen);
	score = match_score + length_score;
}

- (void)setFilterIsFuzzy:(BOOL)aFlag
{
	filterIsFuzzy = aFlag;
	[self updateTitle];
	[self calcScore];
}

- (void)setFilter:(ViRegexpMatch *)m
{
	filter = m;
	[self updateTitle];
	[self calcScore];
}

- (void)setPrefixLength:(NSUInteger)len
{
	prefixLength = len;
	[self updateTitle];
}

- (void)setFont:(NSFont *)aFont
{
	font = aFont;
	[self updateTitle];
}

- (NSUInteger)hash
{
	return [content hash];
}

- (BOOL)isEqual:(id)obj
{
	if (obj == self)
		return YES;
	if ([obj isKindOfClass:[self class]] &&
	    [content isEqualToString:[(ViCompletion *)obj content]])
		return YES;
	return NO;
}

@end
