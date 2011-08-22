#import "ViBundle.h"

@interface ViTheme : NSObject
{
	NSMutableDictionary *theme;
	NSMutableDictionary *themeAttributes;
	NSMutableDictionary *scopeSelectorCache;
	NSMutableDictionary *defaultSettings;
	NSMutableDictionary *smartPairMatchAttributes;
	NSColor *backgroundColor;
	NSColor *foregroundColor;
	NSColor *caretColor;
	NSColor *lineHighlightColor;
	NSColor *selectionColor;
	NSColor *invisiblesColor;
}

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

- (NSDictionary *)invisiblesAttributes;

@end
