#import <Cocoa/Cocoa.h>

#define ViScopeAttributeName @"ViScope"

@interface ViTheme : NSObject
{
	NSDictionary *theme;
	NSMutableDictionary *themeAttributes;
	NSMutableDictionary *scopeSelectorCache;
	NSDictionary *defaultSettings;
	NSColor *backgroundColor;
	NSColor *foregroundColor;
	NSColor *caretColor;
	NSColor *selectionColor;
}
- (id)initWithPath:(NSString *)aPath;
- (id)initWithBundle:(NSString *)aBundleName;
- (NSDictionary *)attributeForScopeSelector:(NSString *)aScopeSelector;
+ (ViTheme *)defaultTheme;
- (NSColor *)backgroundColor;
- (NSColor *)foregroundColor;
- (NSColor *)caretColor;
- (NSColor *)selectionColor;

@end
