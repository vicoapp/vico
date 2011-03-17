#define ViErrorDomain @"se.bzero.ErrorDomain"

@interface ViError : NSObject
{
}

+ (NSError *)errorWithObject:(id)obj;
+ (NSError *)errorWithObject:(id)obj code:(NSInteger)code;
+ (NSError *)errorWithFormat:(NSString *)fmt, ...;
+ (NSError *)errorWithCode:(NSInteger)code format:(NSString *)fmt, ...;
@end

