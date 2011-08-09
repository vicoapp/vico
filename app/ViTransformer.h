#import "ViRegexp.h"

@interface ViTransformer : NSObject
{
}

- (NSString *)transformValue:(NSString *)value
                 withPattern:(ViRegexp *)rx
                      format:(NSString *)format
                      global:(BOOL)global
                       error:(NSError **)outError;

@end

