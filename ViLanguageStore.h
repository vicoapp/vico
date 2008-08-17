#import <Cocoa/Cocoa.h>
#import "ViLanguage.h"

@interface ViLanguageStore : NSObject
{
	NSMutableArray *languages;
}
+ (ViLanguageStore *)defaultStore;
- (ViLanguage *)languageForFilename:(NSString *)aPath;
@end
