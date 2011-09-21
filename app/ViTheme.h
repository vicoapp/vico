#import "ViBundle.h"

@interface ViTheme : NSObject
{
	NSMutableDictionary	*_theme;
	NSMutableDictionary	*_themeAttributes;
	NSMutableDictionary	*_scopeSelectorCache;
	NSMutableDictionary	*_defaultSettings;
	NSMutableDictionary	*_smartPairMatchAttributes;
	NSColor			*_backgroundColor;
	NSColor			*_foregroundColor;
	NSColor			*_caretColor;
	NSColor			*_lineHighlightColor;
	NSColor			*_selectionColor;
	NSColor			*_invisiblesColor;
}

+ (id)themeWithPath:(NSString *)aPath;
- (id)initWithPath:(NSString *)aPath;

- (NSString *)name;
- (NSDictionary *)attributesForScope:(ViScope *)scope inBundle:(ViBundle *)bundle;
- (NSDictionary *)smartPairMatchAttributes;
- (NSColor *)backgroundColor;
- (NSColor *)foregroundColor;
- (NSColor *)caretColor;
- (NSColor *)lineHighlightColor;
- (NSColor *)selectionColor;
- (NSColor *)invisiblesColor;
- (NSString *)description;
- (BOOL)hasDarkBackground;

- (NSDictionary *)invisiblesAttributes;

@end
