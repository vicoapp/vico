#import <Cocoa/Cocoa.h>
#import "ViLanguage.h"

@interface ViLanguageStore : NSObject
{
	NSMutableDictionary *languages;
}
+ (ViLanguageStore *)defaultStore;
- (ViLanguage *)languageForFilename:(NSString *)aPath;
@end
