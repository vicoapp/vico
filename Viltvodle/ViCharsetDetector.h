#import <Cocoa/Cocoa.h>

@interface ViCharsetDetector : NSObject
{
}
+ (ViCharsetDetector *)defaultDetector;
- (NSStringEncoding)encodingForData:(NSData *)data;

@end

