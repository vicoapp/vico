#import <Cocoa/Cocoa.h>

#define ViScopeAttributeName @"ViScope"
#define ViContinuationAttributeName @"ViContinuation"

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
- (NSString *)name;
- (NSDictionary *)attributesForScopes:(NSArray *)scopes;
- (NSColor *)backgroundColor;
- (NSColor *)foregroundColor;
- (NSColor *)caretColor;
- (NSColor *)selectionColor;

@end
