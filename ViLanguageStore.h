#import <Cocoa/Cocoa.h>
#import "ViLanguage.h"

@interface ViLanguageStore : NSObject
{

}
- (ViLanguage *)defaultLanguageForFile:(NSString *)aPath;
@end
