#define ViErrorDomain @"se.bzero.ErrorDomain"

@interface ViError : NSObject
{
}

+ (NSError *)errorWithObject:(id)obj;
+ (NSError *)errorWithFormat:(NSString *)fmt, ...;
@end

