#import <Cocoa/Cocoa.h>
#import "ViLanguage.h"

@interface ViLanguageStore : NSObject
{
	NSMutableDictionary *languages;
	NSMutableArray *bundles;
	NSMutableDictionary *allSmartTypingPairs;
}
+ (ViLanguageStore *)defaultStore;
- (NSMutableDictionary *)bundleForFilename:(NSString *)aPath language:(ViLanguage **)languagePtr;
- (NSMutableDictionary *)bundleForFirstLine:(NSString *)firstLine language:(ViLanguage **)languagePtr;
- (ViLanguage *)languageWithScope:(NSString *)scopeName;
- (NSMutableDictionary *)allSmartTypingPairs;

@end
