#import "ViCompletion.h"
#import "ViThemeStore.h"

@interface ViCompletion (private)
- (void)updateTitle;
@end

@implementation ViCompletion

@synthesize title, content, filter, prefixLength, filterIsFuzzy, font, location;

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

		NSUInteger i;
		for (i = 1; i <= [filter count]; i++) {
			NSRange range = [filter rangeOfSubstringAtIndex:i];
			if (range.length > 0 && range.location != NSNotFound) {
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

- (void)setFilterIsFuzzy:(BOOL)aFlag
{
	filterIsFuzzy = aFlag;
	[self updateTitle];
}

- (void)setFilter:(ViRegexpMatch *)m
{
	filter = m;
	[self updateTitle];
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
