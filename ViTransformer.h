#import "ViRegexp.h"

@interface ViTransformer : NSObject
{
}

- (NSString *)transformValue:(NSString *)value
                 withPattern:(ViRegexp *)rx
                      format:(NSString *)format
                     options:(NSString *)options
                       error:(NSError **)outError;

@end

