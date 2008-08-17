#import <Cocoa/Cocoa.h>


@interface ViLanguage : NSObject
{
	NSMutableDictionary *language;
	NSMutableArray *languagePatterns;
}
- (id)initWithBundle:(NSString *)bundleName;
- (NSArray *)patterns;

@end
