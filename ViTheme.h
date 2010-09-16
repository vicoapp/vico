#import <Cocoa/Cocoa.h>
#import "ViBundle.h"

// FIXME: move to a better place
#define ViSmartPairAttributeName @"ViSmartPair"
#define ViContinuationAttributeName @"ViContinuation"

@interface ViTheme : NSObject
{
	NSDictionary *theme;
	NSMutableDictionary *themeAttributes;
	NSMutableDictionary *scopeSelectorCache;
	NSMutableDictionary *defaultSettings;
	NSColor *backgroundColor;
	NSColor *foregroundColor;
	NSColor *caretColor;
	NSColor *selectionColor;
}

- (id)initWithPath:(NSString *)aPath;
- (NSString *)name;
- (NSDictionary *)attributesForScopes:(NSArray *)scopes inBundle:(ViBundle *)bundle;
- (NSColor *)backgroundColor;
- (NSColor *)foregroundColor;
- (NSColor *)caretColor;
- (NSColor *)selectionColor;
- (NSString *)description;

@end
