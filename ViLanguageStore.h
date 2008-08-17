#import <Cocoa/Cocoa.h>
#import "ViLanguage.h"

@interface ViLanguageStore : NSObject
{
	NSMutableDictionary *languages;
	NSMutableArray *bundles;
	NSMutableDictionary *allSmartTypingPairs;
}
+ (ViLanguageStore *)defaultStore;
- (NSDictionary *)bundleForFilename:(NSString *)aPath language:(ViLanguage **)languagePtr;
- (ViLanguage *)languageWithScope:(NSString *)scopeName;
- (NSMutableDictionary *)allSmartTypingPairs;

@end
