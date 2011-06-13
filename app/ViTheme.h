#import "ViBundle.h"

@interface ViTheme : NSObject
{
	NSDictionary *theme;
	NSMutableDictionary *themeAttributes;
	NSMutableDictionary *scopeSelectorCache;
	NSMutableDictionary *defaultSettings;
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
- (NSColor *)backgroundColor;
- (NSColor *)foregroundColor;
- (NSColor *)caretColor;
- (NSColor *)lineHighlightColor;
- (NSColor *)selectionColor;
- (NSColor *)invisiblesColor;
- (NSString *)description;

- (NSDictionary *)invisiblesAttributes;

@end
