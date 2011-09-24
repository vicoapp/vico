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

+ (id)completionWithContent:(NSString *)aString
{
	return [[[ViCompletion alloc] initWithContent:aString] autorelease];
}

+ (id)completionWithContent:(NSString *)aString fuzzyMatch:(ViRegexpMatch *)aMatch
{
	return [[[ViCompletion alloc] initWithContent:aString fuzzyMatch:aMatch] autorelease];
}

- (id)initWithContent:(NSString *)aString
{
	if ((self = [super init]) != nil) {
		_content = [aString copy];
		_font = [[NSFont userFixedPitchFontOfSize:12] retain];
		_titleParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		[_titleParagraphStyle setLineBreakMode:NSLineBreakByTruncatingHead];
		_markColor = [[NSColor redColor] retain];
		_titleIsDirty = YES;
		_scoreIsDirty = YES;

		if (__separators == nil) {
			__separators = [[NSCharacterSet punctuationCharacterSet] retain];
			__ucase = [[NSCharacterSet uppercaseLetterCharacterSet] retain];
		}
	}
	return self;
}

- (id)initWithContent:(NSString *)aString fuzzyMatch:(ViRegexpMatch *)aMatch
{
	if ([self initWithContent:aString]) {
		_filterMatch = [aMatch retain];
		_filterIsFuzzy = YES;
	}
	return self;
}

- (void)dealloc
{
	[_content release];
	[_title release];
	[_filterMatch release];
	[_font release];
	[_markColor release];
	[_titleParagraphStyle release];
	[super dealloc];
}

- (void)updateTitle
{
	_titleIsDirty = NO;

	if (_prefixLength > [_content length])
		return;

	NSRange grayRange = NSMakeRange(0, _prefixLength);
	if (_filterMatch && !_filterIsFuzzy)
		grayRange.length = _filterMatch.rangeOfMatchedString.length;
	NSColor *gray = [NSColor grayColor];

	[self setTitle:[[[NSMutableAttributedString alloc] initWithString:_content] autorelease]];
	if (grayRange.length > 0)
		[_title addAttribute:NSForegroundColorAttributeName
			       value:gray
			       range:grayRange];

	[_title addAttribute:NSFontAttributeName
		       value:_font
		       range:NSMakeRange(0, [_title length])];

	[_title addAttribute:NSParagraphStyleAttributeName
		       value:_titleParagraphStyle
		       range:NSMakeRange(0, [_title length])];

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
	[m retain];
	[_filterMatch release];
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
	[aFont retain];
	[_font release];
	_font = aFont;
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
