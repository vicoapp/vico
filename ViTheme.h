#import <Cocoa/Cocoa.h>

#define ViScopeAttributeName @"ViScope"

@interface ViTheme : NSObject
{
	NSDictionary *theme;
	NSMutableDictionary *themeAttributes;
	NSMutableDictionary *scopeSelectorCache;
}
- (id)initWithBundle:(NSString *)aBundleName;
- (NSDictionary *)attributeForScopeSelector:(NSString *)aScopeSelector;

@end
