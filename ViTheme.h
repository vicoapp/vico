#import <Cocoa/Cocoa.h>

@interface ViTheme : NSObject
{
	NSDictionary *theme;
	NSMutableDictionary *themeAttributes;
}
- (id)initWithBundle:(NSString *)aBundleName;
- (NSDictionary *)attributeForScopeSelector:(NSString *)aScopeSelector;

@end
